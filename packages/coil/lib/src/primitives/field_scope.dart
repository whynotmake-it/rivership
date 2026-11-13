import 'package:flutter/widgets.dart';

/// What a `CoilField` tells the control inside it.
///
/// `CoilField` puts one above its control slot. Controls read it with
/// [CoilFieldScope.maybeOf] to pick up the field's invalid state, and
/// register what a tap on the field's label does with [CoilFieldControl],
/// the way an HTML `<label for>` focuses its input or toggles its checkbox.
///
/// The field merges its label and description into the control's semantics
/// node itself, so a control doesn't wire its own name from here.
class CoilFieldScope extends InheritedWidget {
  /// Creates a field scope.
  const CoilFieldScope({
    required this.invalid,
    required this.isRequired,
    required this.labelTarget,
    required super.child,
    super.key,
  });

  /// Whether the field has an error: the control shows its invalid look.
  final bool invalid;

  /// Whether the field is marked required.
  final bool isRequired;

  /// Where the field's label sends taps.
  final CoilFieldLabelTarget labelTarget;

  /// The nearest field scope, if any.
  static CoilFieldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilFieldScope>();

  @override
  bool updateShouldNotify(CoilFieldScope oldWidget) =>
      oldWidget.invalid != invalid ||
      oldWidget.isRequired != isRequired ||
      oldWidget.labelTarget != labelTarget;
}

/// Holds the action a field's label performs, registered by the control
/// through [CoilFieldControl]. The last control registered wins.
class CoilFieldLabelTarget {
  VoidCallback? _onLabelTap;

  /// Whether a control has registered a label action.
  bool get hasTarget => _onLabelTap != null;

  /// Runs the control's label action, if any.
  void activate() => _onLabelTap?.call();
}

/// Registers [onLabelTap] with the nearest [CoilFieldScope], so a tap on
/// the field's label runs it: a text field focuses, a checkbox toggles.
class CoilFieldControl extends StatefulWidget {
  /// Creates a field control registration.
  const CoilFieldControl({
    required this.onLabelTap,
    required this.child,
    super.key,
  });

  /// What a tap on the field's label does. Null registers nothing (a
  /// disabled control).
  final VoidCallback? onLabelTap;

  /// The control.
  final Widget child;

  @override
  State<CoilFieldControl> createState() => _CoilFieldControlState();
}

class _CoilFieldControlState extends State<CoilFieldControl> {
  CoilFieldLabelTarget? _target;

  void _onTap() => widget.onLabelTap?.call();

  void _attach() {
    final target = CoilFieldScope.maybeOf(context)?.labelTarget;
    if (target != _target) _detach();
    _target = target;
    target?._onLabelTap = widget.onLabelTap == null ? null : _onTap;
  }

  void _detach() {
    final target = _target;
    if (target != null && target._onLabelTap == _onTap) {
      target._onLabelTap = null;
    }
    _target = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void didUpdateWidget(CoilFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
