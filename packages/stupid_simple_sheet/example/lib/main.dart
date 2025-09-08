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
          )
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
