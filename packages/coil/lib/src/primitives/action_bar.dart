import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/adaptive_popup.dart';
import 'package:coil/src/primitives/modal.dart';
import 'package:coil/src/primitives/sheet.dart';
import 'package:flutter/widgets.dart';

/// How a [CoilActionBar] lays out its buttons.
enum CoilActionBarLayout {
  /// At their own width, trailing-aligned, Cancel before the primary
  /// action; buttons that don't fit wrap onto another trailing row.
  ///
  /// The pointer tier's and wide windows' layout.
  row,

  /// Each button the bar's full width, stacked with the primary action on
  /// top and Cancel at the bottom.
  ///
  /// A phone's layout.
  stack,
}

/// Lays out the buttons that end a dialog or a sheet: a trailing row on
/// the pointer tier and in wide windows, a full-width stack on a phone.
///
/// Give [actions] in reading order, Cancel first and the primary action
/// last, as the row shows them. The stack reverses them, so the primary
/// action is on top and Cancel is at the bottom, where iOS and Android
/// both put it. One action is full width too.
///
/// [layout] overrides the choice; null picks it with [layoutOf].
class CoilActionBar extends StatelessWidget {
  /// Creates an action bar.
  const CoilActionBar({
    required this.actions,
    super.key,
    this.layout,
    this.spacing,
  });

  /// The buttons, Cancel first and the primary action last.
  final List<Widget> actions;

  /// How the buttons lay out; null picks it with [layoutOf].
  final CoilActionBarLayout? layout;

  /// The space between buttons, across and down.
  ///
  /// Null is the tier's [CoilMetrics.gap].
  final double? spacing;

  /// The layout actions at [context] get: [CoilActionBarLayout.stack] in a
  /// sheet or floating panel (a [CoilModalRoute] shown as one, or any
  /// [CoilSheetRoute], such as a popup's) and on the touch tier in a compact
  /// window, where a centered dialog is phone-sized too;
  /// [CoilActionBarLayout.row] elsewhere.
  static CoilActionBarLayout layoutOf(BuildContext context) =>
      (CoilModalRoute.presentationOf(context)?.usesSheetPanel ?? false) ||
          ModalRoute.of(context) is CoilSheetRoute ||
          (CoilTheme.tierOf(context) == CoilTier.touch &&
              MediaQuery.sizeOf(context).width < CoilAdaptivePopup.compactWidth)
      ? CoilActionBarLayout.stack
      : CoilActionBarLayout.row;

  @override
  Widget build(BuildContext context) {
    final spacing = this.spacing ?? CoilTheme.metricsOf(context).gap;
    return switch (layout ?? layoutOf(context)) {
      CoilActionBarLayout.stack => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: actions.reversed.toList(),
      ),
      CoilActionBarLayout.row => Wrap(
        alignment: WrapAlignment.end,
        spacing: spacing,
        runSpacing: spacing,
        children: actions,
      ),
    };
  }
}
