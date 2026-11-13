import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A region that opens and closes its height on a spring: accordion panels,
/// thinking steps, sidebar groups.
///
/// The height springs with `motor_widgets`' `MotionSize` on the theme's
/// `standard` token (`standardExit` closing), and the content fades on
/// `fade` / `fadeExit`. Reduced motion makes the height instant and keeps
/// the fade. [child] stays mounted while closed (its state survives), but it
/// is clipped away, left out of focus traversal and hidden from semantics.
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
