import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

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
    builder: (context, state) => const MotorExample(),
  ),
  NamedRouteDef(
    name: 'Cupertino Sheet',
    path: 'cupertino-sheet',
    builder: (context, data) => _CupertinoSheetContent(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Paged Sheet',
    path: 'paged-sheet',
    builder: (context, data) => _PagedSheetContent(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Small Sheet',
    path: 'small-sheet',
    builder: (context, data) => _SmallSheetContent(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleSheetRoute<T>(
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
    builder: (context, data) => _SnappingSheetContent(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        settings: page,
        snappingConfig: SheetSnappingConfig.relative(
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
    builder: (context, data) => _NonDraggableSheetContent(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        settings: page,
        draggable: false,
        child: child,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
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

class MotorExample extends StatelessWidget {
  const MotorExample({super.key});

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
          ],
        ),
      ),
    );
  }
}

class _CupertinoSheetContent extends StatelessWidget {
  const _CupertinoSheetContent();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Sheet'),
            leading: CupertinoButton(
              child: Text("Close"),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverSafeArea(
              sliver: SliverMainAxisGroup(slivers: [
            SliverToBoxAdapter(
              child: CupertinoTextField(
                placeholder: 'Type something...',
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => CupertinoListTile(
                  title: Text('Item #$index'),
                ),
                childCount: 50,
              ),
            ),
            SliverToBoxAdapter(
              child: CupertinoTextField(),
            ),
          ]))
        ],
      ),
    );
  }
}

class _SnappingSheetContent extends StatefulWidget {
  const _SnappingSheetContent();

  @override
  State<_SnappingSheetContent> createState() => _SnappingSheetContentState();
}

class _SnappingSheetContentState extends State<_SnappingSheetContent> {
  bool _snapDisabled = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Sheet'),
            trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(_snapDisabled ? 'Enable Snaps' : 'Disable Snaps'),
                onPressed: () {
                  final controller =
                      StupidSimpleSheetController.maybeOf(context);
                  controller
                      ?.overrideSnappingConfig(
                        _snapDisabled ? null : SheetSnappingConfig.full,
                        animateToComply: true,
                      )
                      .ignore();
                  setState(() {
                    _snapDisabled = !_snapDisabled;
                  });
                }),
            leading: CupertinoButton(
              child: Text("Close"),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: CupertinoButton.tinted(
                child: Text('Another'),
                onPressed: () =>
                    context.pushRoute(NamedRoute('Snapping Sheet')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagedSheetContent extends StatelessWidget {
  const _PagedSheetContent();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: PageView(
        children: [
          CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CupertinoListTile(
                    title: Text('Item #$index'),
                  ),
                  childCount: 50,
                ),
              ),
            ],
          ),
          CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CupertinoListTile(
                    title: Text('Item #$index'),
                  ),
                  childCount: 50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NonDraggableSheetContent extends StatelessWidget {
  const _NonDraggableSheetContent();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Non-Draggable Sheet'),
            leading: CupertinoButton(
              child: Text("Close"),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  Text(
                    'This sheet cannot be dragged!',
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Use the Close button to dismiss.',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(color: CupertinoColors.secondaryLabel),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallSheetContent extends StatefulWidget {
  const _SmallSheetContent();

  @override
  State<_SmallSheetContent> createState() => _SmallSheetContentState();
}

class _SmallSheetContentState extends State<_SmallSheetContent> {
  int _itemCount = 5;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.all(8),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: CupertinoMotion.smooth().duration,
                  curve: CupertinoMotion.smooth().toCurve,
                  child: Column(
                    children: [
                      CupertinoTextField(
                        autofocus: true,
                        placeholder: 'Type something...',
                      ),
                      for (var i = 0; i < _itemCount; i++)
                        CupertinoListTile(
                          title: Text('Item #${i + 1}'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              color: CupertinoColors.opaqueSeparator,
              height: 1,
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    foregroundColor: CupertinoColors.destructiveRed,
                    child: Text('Close'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                Expanded(
                  child: CupertinoButton(
                    child: Text('Add Item'),
                    onPressed: () {
                      setState(() {
                        _itemCount++;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
