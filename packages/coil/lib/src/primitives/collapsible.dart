import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A region whose height springs open and closed, for accordion panels,
/// thinking steps and sidebar groups.
///
/// The height uses the `standard` spring and the content fades. Under
/// reduced motion only the fade remains.
///
/// [child] stays mounted while closed, so its state survives. It can't be
/// focused or read by screen readers until it opens.
class CoilCollapsible extends StatelessWidget {
  /// Creates a collapsible region.
  const CoilCollapsible({
    required this.expanded,
    required this.child,
    super.key,
    this.motion,
    this.debugLabel,
  });

  /// Whether the region is open.
  final bool expanded;

  /// The content.
  final Widget child;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context, override: this.motion);
    final label = debugLabel ?? 'CoilCollapsible';
    return MotionSize(
      motion: expanded ? motion.standard : motion.standardExit,
      alignment: Alignment.topCenter,
      debugLabel: '$label.height',
      child: ClipRect(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: expanded ? 1 : 0,
          child: ExcludeFocus(
            excluding: !expanded,
            child: ExcludeSemantics(
              excluding: !expanded,
              child: SingleMotionBuilder(
                value: expanded ? 1 : 0,
                motion: expanded ? motion.fade : motion.fadeExit,
                debugLabel: '$label.opacity',
                child: child,
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
