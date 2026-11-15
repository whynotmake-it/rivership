import 'package:coil/src/primitives/interaction.dart';
import 'package:flutter/widgets.dart';

/// What a `CoilField` tells its control: whether the field is invalid or
/// required, and where its label sends taps.
///
/// A control shows its invalid look when [invalid] is true, and wraps
/// itself in [CoilFieldControl] so a tap on the label reaches it. The field
/// handles semantics itself, so controls don't read their label from here.
///
/// A field drawn as a container (a `CoilChoiceCard`) or a row
/// ([CoilFieldRow]) also tells its control when the pointer is over it
/// ([containerHovered]) or presses it ([containerPressed]). A container
/// that also draws the focus ring says so with [framed].
class CoilFieldScope extends InheritedWidget {
  /// Creates a field scope.
  const CoilFieldScope({
    required this.invalid,
    required this.isRequired,
    required this.labelTarget,
    required super.child,
    super.key,
    this.framed = false,
    this.containerHovered = false,
    this.containerPressed = false,
  });

  /// Whether the field has an error: the control shows its invalid look.
  final bool invalid;

  /// Whether the field is marked required.
  final bool isRequired;

  /// Where the field's label sends taps.
  final CoilFieldLabelTarget labelTarget;

  /// Whether the field is a container that frames its control: the whole
  /// container is the tap target and draws the focus ring. The control then
  /// leaves out its own ring, so one shows, and its hit-area padding.
  final bool framed;

  /// Whether a hovering pointer is over the field's container. The control
  /// shows its hover look, as if the pointer were on it.
  final bool containerHovered;

  /// Whether the field's container is pressed outside the control. The
  /// control shows its pressed look, as if the press were on it.
  final bool containerPressed;

  /// The nearest field scope, if any.
  static CoilFieldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilFieldScope>();

  @override
  bool updateShouldNotify(CoilFieldScope oldWidget) =>
      oldWidget.invalid != invalid ||
      oldWidget.isRequired != isRequired ||
      oldWidget.labelTarget != labelTarget ||
      oldWidget.framed != framed ||
      oldWidget.containerHovered != containerHovered ||
      oldWidget.containerPressed != containerPressed;
}

/// Where a tap reaches a field's control.
enum CoilFieldTapArea {
  /// The label only. A text field focuses and a copy field copies; a tap
  /// elsewhere in the row does nothing, so a slider or a select can't be
  /// changed by a tap that missed it.
  label,

  /// The field's whole row: a checkbox, switch or radio toggles from
  /// anywhere in a [CoilFieldRow], as in a native settings list.
  row,
}

/// The controls a field holds, registered through [CoilFieldControl]. A
/// tap on the label runs the last one's action; a tap on the row runs it
/// only for a single control that takes row taps.
class CoilFieldLabelTarget {
  final _controls = <_CoilFieldControlState>[];

  _CoilFieldControlState? get _single =>
      _controls.length == 1 ? _controls.single : null;

  /// Runs the control's label action, if any.
  void activate() =>
      (_controls.isEmpty ? null : _controls.last.widget.onLabelTap)?.call();

  /// Whether a tap on the field's row reaches its control: the field holds
  /// one enabled control whose [CoilFieldControl.tapArea] is the row.
  bool get takesRowTaps {
    final control = _single?.widget;
    return control != null &&
        control.onLabelTap != null &&
        control.tapArea == CoilFieldTapArea.row;
  }

  /// Runs the control's action when [takesRowTaps].
  void activateRow() {
    if (takesRowTaps) _single!.widget.onLabelTap!();
  }
}

/// Registers [child] as its field's control. A tap on the field's label
/// runs [onLabelTap], like an HTML `<label for>`: a text field focuses
/// itself, a checkbox toggles. With [tapArea] [CoilFieldTapArea.row], a tap
/// anywhere in a [CoilFieldRow] runs it too.
class CoilFieldControl extends StatefulWidget {
  /// Creates a field control registration.
  const CoilFieldControl({
    required this.onLabelTap,
    required this.child,
    super.key,
    this.tapArea = CoilFieldTapArea.label,
  });

  /// What a tap on the field's label does. Null does nothing (a disabled
  /// control).
  final VoidCallback? onLabelTap;

  /// Where a tap reaches the control.
  final CoilFieldTapArea tapArea;

  /// The control.
  final Widget child;

  @override
  State<CoilFieldControl> createState() => _CoilFieldControlState();
}

// The target reads the registered widget when a tap lands, so a control
// that changes needs no re-registration, and registering notifies no one.
class _CoilFieldControlState extends State<CoilFieldControl> {
  CoilFieldLabelTarget? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final target = CoilFieldScope.maybeOf(context)?.labelTarget;
    if (target == _target) return;
    _detach();
    _target = target?.._controls.add(this);
  }

  void _detach() {
    _target?._controls.remove(this);
    _target = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Makes a field's row one tap target for its toggle, like a native
/// settings row: a tap anywhere in [child] (the padding, the gap, the
/// description) toggles the control, and the control shows hover and press
/// while the row has them. The control keeps its own focus and ring.
///
/// Only a field with one control that takes row taps
/// ([CoilFieldLabelTarget.takesRowTaps]) responds. A row with a text
/// field, a select, a slider or several controls stays inert outside them.
///
/// Put it under the field's [CoilFieldScope].
class CoilFieldRow extends StatefulWidget {
  /// Makes [child] a tap target for the enclosing field's control.
  const CoilFieldRow({required this.child, super.key});

  /// The row: the label, the description and the control.
  final Widget child;

  @override
  State<CoilFieldRow> createState() => _CoilFieldRowState();
}

class _CoilFieldRowState extends State<CoilFieldRow> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = CoilFieldScope.maybeOf(context);
    if (field == null) return widget.child;
    final target = field.labelTarget;
    // The control registers while it builds, after this row. Hover and
    // press rebuild the row, so its look reads the control as it is then.
    return ListenableBuilder(
      listenable: _states,
      child: widget.child,
      builder: (context, child) {
        final active = target.takesRowTaps;
        final states = CoilInteractionDetector.statesFor(
          _states.value,
          enabled: active,
        );
        // The detector stays enabled, so it sees the first hover even
        // before the control has registered; the look is masked instead.
        return CoilInteractionDetector(
          states: _states,
          onTap: target.activateRow,
          cursor: active ? null : MouseCursor.defer,
          // The control carries the action in semantics.
          excludeFromSemantics: true,
          child: CoilFieldScope(
            invalid: field.invalid,
            isRequired: field.isRequired,
            labelTarget: target,
            framed: field.framed,
            containerHovered: states.contains(WidgetState.hovered),
            containerPressed: states.contains(WidgetState.pressed),
            child: child!,
          ),
        );
      },
    );
  }
}
