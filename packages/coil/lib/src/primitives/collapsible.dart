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

  /// Called when the height settles after a change of [expanded].
  final VoidCallback? onEnd;

  /// The height's motion. Defaults to `standard` opening and
  /// `standardExit` closing.
  final Motion? heightMotion;

  /// The opacity's motion. Defaults to `fade` opening and `fadeExit`
  /// closing.
  final Motion? opacityMotion;

  /// How long the fade in waits after the height starts to open.
  final Duration opacityDelay;

  /// Overrides the theme's motion tokens for the default motions.
  final CoilMotion? motion;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  State<CoilCollapsible> createState() => _CoilCollapsibleState();
}

class _CoilCollapsibleState extends State<CoilCollapsible> {
  static final _height = Track<double>(
    MotionConverter.single,
    debugLabel: 'CoilCollapsible.height',
  );
  static final _opacity = Track<double>(
    MotionConverter.single,
    debugLabel: 'CoilCollapsible.opacity',
  );

  /// Whether the first build is done: only it may start somewhere other
  /// than where the tracks are.
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final expanded = widget.expanded;
    final target = expanded ? 1.0 : 0.0;
    final from = _built ? null : (widget.appear ? 0.0 : target);
    _built = true;
    final onEnd = widget.onEnd;
    return TrackBuilder(
      debugLabel: widget.debugLabel ?? 'CoilCollapsible',
      animations: [
        _height(
          [
            .to(
              target,
              motion:
                  widget.heightMotion ??
                  (expanded ? tokens.standard : tokens.standardExit),
            ),
          ],
          from: from,
        ),
        _opacity(
          [
            .to(
              target,
              motion:
                  widget.opacityMotion ??
                  (expanded ? tokens.fade : tokens.fadeExit),
            ),
          ],
          from: from,
          delay: expanded ? widget.opacityDelay : Duration.zero,
        ),
      ],
      onAnimationStatusChanged: onEnd == null
          ? null
          : (status) {
              if (status.isCompleted || status.isDismissed) onEnd();
            },
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: math.max(0, value(_height)),
          child: Opacity(
            opacity: value(_opacity).clamp(0.0, 1.0),
            child: child,
          ),
        ),
      ),
      child: ExcludeFocus(
        excluding: !expanded,
        child: ExcludeSemantics(excluding: !expanded, child: widget.child),
      ),
    );
  }
}
