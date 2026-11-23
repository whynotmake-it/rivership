import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Builds with how far the software keyboard covers the bottom of the box
/// [builder] returns, in logical pixels: zero when the box ends above the
/// keyboard's top or no keyboard is up.
///
/// Use it to pad the end of a scroll view whose bottom sits under the
/// keyboard, so its last field can scroll above it while the content keeps
/// drawing behind the keyboard. `CoilScrollArea(keyboardInset: true)` does
/// this for you; use the widget directly for a list of your own:
///
/// ```dart
/// CoilKeyboardOverlap(
///   builder: (context, overlap, _) => ListView(
///     padding: EdgeInsets.only(bottom: overlap),
///     children: fields,
///   ),
/// )
/// ```
///
/// The overlap is measured, not taken from the keyboard's height: it is the
/// keyboard's top, from the view's insets, against the box's bottom, both in
/// global coordinates. A box that ends above a footer gets only the part of
/// the keyboard that reaches it, and one in a sheet that already rides on
/// the keyboard gets none. Each box measures itself, so nested ones don't
/// add up: each pads only what covers its own viewport.
///
/// The keyboard animates in through metrics changes, a frame at a time, and
/// the overlap follows it in the same frame with no motion of its own. The
/// box's position is the one it had in the last frame, measured again after
/// every build.
class CoilKeyboardOverlap extends StatefulWidget {
  /// Builds [builder] with the keyboard's overlap of what it returns.
  const CoilKeyboardOverlap({required this.builder, super.key, this.child});

  /// Builds the box with the current overlap.
  final ValueWidgetBuilder<double> builder;

  /// Passed to [builder] as is, for a part that doesn't depend on the
  /// overlap.
  final Widget? child;

  /// How far the keyboard of [context]'s view covers the bottom of [box],
  /// as laid out in the last frame; zero if [box] isn't laid out.
  static double measure(BuildContext context, RenderBox? box) {
    final view = View.maybeOf(context);
    if (view == null || box == null || !box.attached || !box.hasSize) {
      return 0;
    }
    final ratio = view.devicePixelRatio;
    final keyboard = view.viewInsets.bottom / ratio;
    if (keyboard <= 0) return 0;
    final keyboardTop = view.physicalSize.height / ratio - keyboard;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    return clampDouble(bottom - keyboardTop, 0, keyboard);
  }

  @override
  State<CoilKeyboardOverlap> createState() => _CoilKeyboardOverlapState();
}

class _CoilKeyboardOverlapState extends State<CoilKeyboardOverlap>
    with WidgetsBindingObserver {
  double _overlap = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The view's insets, not the ambient MediaQuery's: an ancestor may have
  // taken them out of it.
  @override
  void didChangeMetrics() => setState(() {});

  RenderBox? get _box {
    final box = context.findRenderObject();
    return box is RenderBox ? box : null;
  }

  /// After layout, where the box ended up may have changed the overlap.
  void _remeasure(Duration _) {
    if (!mounted) return;
    final overlap = CoilKeyboardOverlap.measure(context, _box);
    if (overlap != _overlap) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _overlap = CoilKeyboardOverlap.measure(context, _box);
    SchedulerBinding.instance.addPostFrameCallback(
      _remeasure,
      debugLabel: 'CoilKeyboardOverlap.remeasure',
    );
    return widget.builder(context, _overlap, widget.child);
  }
}
