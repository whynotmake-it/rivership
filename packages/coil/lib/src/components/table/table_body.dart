import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/table/table_column.dart';
import 'package:coil/src/components/table/table_row.dart';
import 'package:coil/src/components/table/table_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The body: the rows over the table's highlight, selection and focus ring
/// layer. The keyboard's focus ring sits on the [active] row while the
/// keyboard drives it, inset because the table clips.
class TableBody<T> extends StatelessWidget {
  /// Creates the body.
  const TableBody({
    required this.rows,
    required this.values,
    required this.columns,
    required this.widths,
    required this.metrics,
    required this.style,
    required this.active,
    required this.focusNode,
    required this.selection,
    required this.ring,
    required this.motion,
    required this.highlightMotion,
    required this.ringMotion,
    required this.rowMotions,
    required this.onTap,
    super.key,
  });

  /// The rows' data, in order.
  final List<T> rows;

  /// The selected rows.
  final Set<T> values;

  /// The columns.
  final List<CoilTableColumn<T>> columns;

  /// The resolved column widths.
  final List<double> widths;

  /// The table's metrics.
  final CoilMetrics metrics;

  /// The table's resolved style.
  final CoilTableStyle style;

  /// The active row.
  final CoilActiveItemController active;

  /// The table's focus node.
  final FocusNode focusNode;

  /// Paints the selected rows' blocks.
  final CoilSelectionPainter selection;

  /// Paints the keyboard's focus ring.
  final CoilHighlightPainter ring;

  /// The table's motion tokens, for the ring's fades.
  final CoilMotion motion;

  /// The highlight's glide.
  final Motion highlightMotion;

  /// The ring's travel between rows.
  final Motion ringMotion;

  /// The rows' own motions.
  final TableRowMotions rowMotions;

  /// Called with a tapped row; null makes the rows inert.
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        active,
        focusNode,
        CoilInputModality.instance,
      ]),
      builder: (context, child) {
        ring.update(
          target:
              focusNode.hasPrimaryFocus &&
                  active.keyboardDriven &&
                  CoilInputModality.instance.value == CoilModality.keyboard
              ? active.index
              : null,
          fadeIn: false,
          motion: ringMotion,
          exitMotion: motion.fadeExit,
          exitTravelMotion: ringMotion,
          fade: motion.fade,
          inflate: -style.ringInset!,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(
                style.radius! - style.ringInset!,
              ),
              side: BorderSide(
                color: theme.colors.focusRing,
                width: theme.focusRingWidth,
              ),
            ),
          ),
        );
        return child!;
      },
      child: CoilHoverRegion(
        activeItem: active,
        followFocus: false,
        child: CoilHoverHighlight(
          color: style.highlight,
          radius: style.radius,
          glideMotion: highlightMotion,
          background: [selection],
          foreground: [ring],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, row) in rows.indexed)
                CoilHoverItem(
                  key: ValueKey<T>(row),
                  index: i,
                  child: TableBodyRow<T>(
                    index: i,
                    row: row,
                    columns: columns,
                    widths: widths,
                    selected: values.contains(row),
                    nextSelected:
                        i + 1 < rows.length && values.contains(rows[i + 1]),
                    last: i == rows.length - 1,
                    metrics: metrics,
                    style: style,
                    motions: rowMotions,
                    onPressed: onTap == null ? null : () => onTap!(row),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
