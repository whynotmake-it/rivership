import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:heroine_example/src/icons.dart';

/// The crown and "Heroine" in the picker's header. With [onHome] it is a
/// link back to the app around the example, with coil's hover, press and
/// focus states; without it, it is inert.
class HeroineBrand extends StatelessWidget {
  const HeroineBrand({super.key, this.onHome});

  /// Leads back to the app that mounts the example, if any.
  final VoidCallback? onHome;

  /// How far the crown's ink sits in from the brand's start edge: the row's
  /// item padding plus the empty space Lucide's crown leaves on its start
  /// side (its stroke starts 2 into the 24-unit grid). The header pulls the
  /// brand toward the edge by this, so the crown lines up with the content.
  static double inkInsetOf(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    return metrics.itemPaddingX + _markSize(metrics) * 2 / 24;
  }

  static double _markSize(CoilMetrics metrics) => metrics.iconSize + 4;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.controlHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: metrics.itemPaddingX,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(
              // The app's icon theme may carry an accent (Cupertino's primary blue);
              // the mark is part of the wordmark, so it takes the text color.
              data: IconThemeData(
                size: _markSize(metrics),
                color: colors.foreground,
              ),
              child: const DemoIcon(Glyph.crown),
            ),
            SizedBox(width: metrics.gap),
            Flexible(
              child: Text(
                'Heroine',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.title,
              ),
            ),
          ],
        ),
      ),
    );
    final onHome = this.onHome;
    if (onHome == null) {
      return Semantics(
        header: true,
        label: 'Heroine',
        excludeSemantics: true,
        child: row,
      );
    }
    return Semantics(
      button: true,
      label: 'Back to all packages',
      onTap: onHome,
      excludeSemantics: true,
      child: CoilInteraction(
        onPressed: onHome,
        excludeFromSemantics: true,
        child: row,
        builder: (context, states, child) => CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: states.contains(WidgetState.pressed)
                  ? colors.active
                  : states.contains(WidgetState.hovered)
                  ? colors.hover
                  : null,
              shape: RoundedSuperellipseBorder(borderRadius: radius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
