import 'package:coil/src/foundation/input_modality.dart';
import 'package:flutter/widgets.dart';

/// Tells [builder] whether visible focus is inside [child]: the container
/// version of the focus ring, like CSS `:has(:focus-visible)`.
///
/// It's true while something in [child] has focus and either the keyboard
/// was the last input (`CoilInputModality`, the same rule as a control's
/// ring) or the focused thing is a text field, which shows its focus
/// however it got it. A click or tap on a button inside never turns it on.
///
/// Use it to outline a container (a choice card, a panel) while the user
/// works inside it. It adds no focus stop of its own.
///
/// ```dart
/// CoilFocusWithin(
///   builder: (context, visible, child) => CoilFocusRing(
///     visible: visible,
///     borderRadius: radius,
///     child: child!,
///   ),
///   child: form,
/// )
/// ```
class CoilFocusWithin extends StatefulWidget {
  /// Creates a focus-within detector.
  const CoilFocusWithin({required this.builder, super.key, this.child});

  /// Builds the container from whether focus inside it is visible.
  final ValueWidgetBuilder<bool> builder;

  /// The subtree to watch, passed through to [builder].
  final Widget? child;

  @override
  State<CoilFocusWithin> createState() => _CoilFocusWithinState();
}

class _CoilFocusWithinState extends State<CoilFocusWithin> {
  final _node = FocusNode(
    debugLabel: 'CoilFocusWithin',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _modality = CoilInputModality.instance;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _modality.addListener(_sync);
    // The primary focus can move between two children without this node's
    // own focus changing, which matters when one of them is a text field.
    FocusManager.instance.addListener(_sync);
  }

  @override
  void dispose() {
    _modality.removeListener(_sync);
    FocusManager.instance.removeListener(_sync);
    _node.dispose();
    super.dispose();
  }

  void _sync() {
    final visible =
        _node.hasFocus &&
        (_modality.value == CoilModality.keyboard || _textFieldFocused());
    if (visible != _visible && mounted) setState(() => _visible = visible);
  }

  static bool _textFieldFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final editable = primary?.context
        ?.findAncestorWidgetOfExactType<EditableText>();
    return editable != null && editable.focusNode == primary;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    includeSemantics: false,
    child: widget.builder(context, _visible, widget.child),
  );
}
