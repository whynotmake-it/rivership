import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns the current page of a [PageController].
///
/// Returns `null` if the [PageController] has no clients or if the
/// [PageController] has no dimensions.
double usePage(PageController controller) {
  final pc = useListenable(controller);
  return pc.positions.isNotEmpty && pc.position.haveDimensions
      ? pc.page ?? pc.initialPage.toDouble()
      : pc.initialPage.toDouble();
}
