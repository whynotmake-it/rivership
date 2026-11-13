import 'dart:math' as math;

import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A region that opens and closes by springing its height.
///
/// The height is a 0 to 1 factor of the child's own height, so a child
/// that resizes while the region is open resizes at once. The content
/// fades with it. Under reduced motion only the fade remains.
///
/// [child] stays mounted while closed, so its state survives. It can't be
/// focused or read by screen readers until it opens.
class CoilCollapsible extends StatefulWidget {
  /// Creates a collapsible region.
  const CoilCollapsible({
    required this.expanded,
    required this.child,
    super.key,
    this.appear = false,
    this.onEnd,
    this.heightMotion,
    this.opacityMotion,
    this.opacityDelay = Duration.zero,
    this.fade = true,
    this.motion,
    this.debugLabel,
  });

  /// Whether the region is open.
  final bool expanded;

  /// The content.
  final Widget child;

  /// Whether a region that is open when it first builds opens from closed
  /// instead of showing at once: a new step or message arriving.
  final bool appear;

  /// Called when the height settles open or closed after [expanded]
  /// changed to that state.
  final VoidCallback? onEnd;

  /// The height's motion. Defaults to `standard` opening and
  /// `standardExit` closing.
  final Motion? heightMotion;

  /// The opacity's motion. Defaults to `fade` opening and `fadeExit`
  /// closing.
  final Motion? opacityMotion;

  /// How long the fade in waits after the height starts to open.
  final Duration opacityDelay;

  /// Whether the content fades with the height. Turn it off when the
  /// content brings its own exit, such as a blur-fade.
  final bool fade;

  /// Overrides the theme's motion tokens for the default motions.
  final CoilMotion? motion;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  State<CoilCollapsible> createState() => _CoilCollapsibleState();
}

class _CoilCollapsibleState extends State<CoilCollapsible> {
  // Per region, so each starts where its own first build says.
  late final Track<double> _height;
  late final Track<double> _opacity;

  @override
  void initState() {
    super.initState();
    final start = widget.appear || !widget.expanded ? 0.0 : 1.0;
    _height = Track<double>(
      MotionConverter.single,
      initial: start,
      debugLabel: 'CoilCollapsible.height',
    );
    _opacity = Track<double>(
      MotionConverter.single,
      initial: start,
      debugLabel: 'CoilCollapsible.opacity',
    );
  }

  /// Whether [CoilCollapsible.expanded] changed and the height hasn't
  /// settled since.
  bool _changed = false;

  @override
  void didUpdateWidget(CoilCollapsible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _changed = true;
  }

  void _onStatus(AnimationStatus status) {
    // The tracks' combined status: the first settle after a change is the
    // end of that change, whichever way the last track moved.
    if (!_changed || status.isAnimating) return;
    _changed = false;
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final expanded = widget.expanded;
    final target = expanded ? 1.0 : 0.0;
    return TrackBuilder(
      debugLabel: widget.debugLabel ?? 'CoilCollapsible',
      animations: [
        _height([
          .to(
            target,
            motion:
                widget.heightMotion ??
                (expanded ? tokens.standard : tokens.standardExit),
          ),
        ]),
        _opacity(
          [
            .to(
              target,
              motion:
                  widget.opacityMotion ??
                  (expanded ? tokens.fade : tokens.fadeExit),
            ),
          ],
          delay: expanded ? widget.opacityDelay : Duration.zero,
        ),
      ],
      onAnimationStatusChanged: widget.onEnd == null ? null : _onStatus,
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: math.max(0, value(_height)),
          child: widget.fade
              ? Opacity(
                  opacity: value(_opacity).clamp(0.0, 1.0),
                  child: child,
                )
              : child,
        ),
      ),
      child: ExcludeFocus(
        excluding: !expanded,
        child: ExcludeSemantics(excluding: !expanded, child: widget.child),
      ),
    );
  }
}
