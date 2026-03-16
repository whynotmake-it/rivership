import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/shrinking_modal_example.dart';

import 'cupertino_sheet_example.dart';
import 'glass_sheet_example.dart';
import 'non_draggable_sheet_example.dart';
import 'paged_sheet_example.dart';
import 'resizing_sheet_example.dart';
import 'shrink_sheet_example.dart';
import 'snapping_sheet_example.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CupertinoApp.router(
      routerConfig: router.config(),
    ),
  );
}

final stupidSimpleSheetRoutes = [
  NamedRouteDef(
    name: 'Stupid Simple Sheet Examples',
    path: '',
    type: RouteType.cupertino(),
    builder: (context, state) => const ExampleApp(),
  ),
  NamedRouteDef(
    name: 'Glass Sheet',
    path: 'glass-sheet',
    builder: (context, data) => GlassSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleGlassSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Cupertino Sheet',
    path: 'cupertino-sheet',
    builder: (context, data) => CupertinoSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Paged Sheet',
    path: 'paged-sheet',
    builder: (context, data) => PagedSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Small Sheet',
    path: 'small-sheet',
    builder: (context, data) => ResizingSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.settled,
        settings: page,
        motion: CupertinoMotion.smooth(),
        originateAboveBottomViewInset: true,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Snapping Sheet',
    path: 'snapping-sheet',
    builder: (context, data) => SnappingSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        snappingConfig: SheetSnappingConfig(
          [0.5, 1.0],
          initialSnap: .5,
        ),
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Non-Draggable Sheet',
    path: 'non-draggable-sheet',
    builder: (context, data) => NonDraggableSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        draggable: false,
        child: child,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Shrink Sheet',
    path: 'shrink-sheet',
    builder: (context, data) => ShrinkSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleGlassSheetRoute<T>(
        snappingConfig: SheetSnappingConfig([.5, 1]),
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        dismissalMode: DismissalMode.shrink,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Shrink Modal',
    path: 'shrink-modal',
    builder: (context, data) => ShrinkingModalExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) => ShrinkingModalRoute<T>(
        settings: page,
        child: child,
      ),
    ),
  ),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: RouteType.cupertino(),
      children: stupidSimpleSheetRoutes,
    ),
  ],
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar.large(
        largeTitle: Text('Stupid Simple Sheet'),
      ),
      child: Center(
        child: Column(
          spacing: 16,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoButton.filled(
              child: Text('Glass Sheet'),
              onPressed: () => context.navigateTo(NamedRoute('Glass Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Cupertino Sheet'),
              onPressed: () =>
                  context.navigateTo(NamedRoute('Cupertino Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Paged Sheet'),
              onPressed: () => context.navigateTo(NamedRoute('Paged Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Resizing Sheet'),
              onPressed: () => context.navigateTo(NamedRoute('Small Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Snapping Sheet'),
              onPressed: () => context.navigateTo(NamedRoute('Snapping Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Non-Draggable Sheet'),
              onPressed: () =>
                  context.navigateTo(NamedRoute('Non-Draggable Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Shrink Sheet'),
              onPressed: () => context.navigateTo(NamedRoute('Shrink Sheet')),
            ),
            CupertinoButton.filled(
              child: Text('Shrink Modal'),
              onPressed: () => context.navigateTo(NamedRoute('Shrink Modal')),
            )
          ],
        ),
      ),
    );
  }
}
