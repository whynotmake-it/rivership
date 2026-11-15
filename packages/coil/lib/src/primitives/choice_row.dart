import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A row with a leading control and a label.
///
/// The label is muted at rest and semibold when [selected]; a hidden
/// semibold copy keeps the row's width and wrapping the same either way.
/// The row is at least a control tall and grows with long or large text.
class CoilChoiceRow extends StatelessWidget {
  /// Creates a row.
  const CoilChoiceRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.labelStyle,
    required this.labelColor,
    required this.labelMotion,
    super.key,
    this.size,
  });

  /// The control at the row's start.
  final Widget leading;

  /// The label.
  final Widget label;

  /// Whether the label shows its selected weight.
  final bool selected;

  /// The label's text style; the color comes from [labelColor].
  final TextStyle labelStyle;

  /// The label's current color. Changes fade.
  final Color labelColor;

  /// The motion of the label's color and weight.
  final Motion labelMotion;

  /// Pins the row to one size step. Null follows `CoilAdaptiveScope`.
  final CoilSize? size;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: size);
    final semibold = labelStyle.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.controlHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.itemPaddingX,
          vertical: metrics.controlPaddingY(metrics.body),
        ),
        child: Row(
          spacing: metrics.gap,
          children: [
            leading,
            Expanded(
              child: MotionBuilder<Color>(
                value: labelColor,
                converter: MotionConverter.colorRgb,
                motion: labelMotion,
                debugLabel: 'CoilChoiceRow label color',
                builder: (context, color, _) => SingleMotionBuilder(
                  value: selected ? 1 : 0,
                  motion: labelMotion,
                  debugLabel: 'CoilChoiceRow label weight',
                  builder: (context, t, _) => Stack(
                    children: [
                      Opacity(
                        opacity: 0,
                        child: ExcludeSemantics(
                          child: DefaultTextStyle(
                            style: semibold,
                            child: label,
                          ),
                        ),
                      ),
                      DefaultTextStyle(
                        style: labelStyle.copyWith(
                          color: color,
                          fontVariations: [
                            FontVariation(
                              'wght',
                              _lerp(
                                CoilWeight.normal.wght,
                                CoilWeight.semibold.wght,
                                t,
                              ),
                            ),
                            FontVariation(
                              'opsz',
                              _lerp(
                                CoilWeight.normal.opsz,
                                CoilWeight.semibold.opsz,
                                t,
                              ),
                            ),
                          ],
                        ),
                        child: label,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
