import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A two-line row on the home screen: title, summary and a chevron. Built
/// on [CoilInteraction], so it hovers, presses and shows its focus ring by
/// coil's rules. A null [onPressed] shows the row as planned.
///
/// coil has no list row component yet (Sidebar and menus will bring one),
/// so this is the catalog's own.
class NavRow extends StatelessWidget {
  const NavRow({
    required this.title,
    required this.summary,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String summary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    final enabled = onPressed != null;
    return CoilInteraction(
      onPressed: onPressed,
      builder: (context, states, child) {
        final motion = CoilTheme.motionOf(context);
        final fill = states.contains(WidgetState.pressed)
            ? colors.active
            : states.contains(WidgetState.hovered)
            ? colors.hover
            : colors.hover.withValues(alpha: 0);
        final lit = fill.a > 0;
        return CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          offset: 2,
          child: MotionBuilder<Color>(
            value: fill,
            motion: lit ? motion.fade : motion.fadeExit,
            converter: MotionConverter.colorRgb,
            debugLabel: 'NavRow.fill',
            builder: (context, color, child) => DecoratedBox(
              decoration: ShapeDecoration(
                color: color,
                shape: RoundedSuperellipseBorder(borderRadius: radius),
              ),
              child: child,
            ),
            child: child,
          ),
        );
      },
      child: Semantics(
        // A planned row is listed, not disabled: it can't be opened yet.
        hint: enabled ? null : 'Planned',
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: metrics.itemPaddingX,
              vertical: metrics.tier == CoilTier.touch ? 8 : 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeRole.body.styleOf(
                          context,
                          weight: CoilWeight.semibold,
                        ),
                      ),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TypeRole.caption.styleOf(
                          context,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: metrics.gap),
                if (enabled)
                  IconTheme(
                    data: IconThemeData(
                      size: metrics.iconSize,
                      color: colors.mutedForeground,
                      applyTextScaling: true,
                    ),
                    child: const CatalogIcon(Glyph.forward),
                  )
                else
                  const RoleText(
                    'Planned',
                    role: TypeRole.caption,
                    muted: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
