import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:rivership/rivership.dart';
import 'package:rivership/src/hooks/use_keyed_state.dart';
import 'package:rivership/src/hooks/use_on_listenable_change.dart';

/// Returns the current page of a [PageController].
///
/// Returns `null` if the [PageController] has no clients or if the
/// [PageController] has no dimensions.
double usePage(PageController controller) {
  final pc = useListenable(controller);
  return pc.tryPage;
}

/// Returns the current whole page of a [PageController] as an integer.
///
/// Only triggers a rebuild when that changes, not for the inbetween values
/// during transitions.
int usePageIndex(PageController controller) {
  final initialPage = useKeyedState(
    controller.tryPage.round(),
    keys: [controller],
  );

  useOnListenableChange(controller, () {
    if (initialPage.value != controller.tryPage.round()) {
      initialPage.value = controller.tryPage.round();
    }
  });
  return initialPage.value;
}

extension on PageController {
  double get tryPage => positions.isNotEmpty && position.haveDimensions
      ? page ?? initialPage.toDouble()
      : initialPage.toDouble();
}
