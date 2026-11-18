import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

final _sheetTypes = <String,
    PopupRoute<T> Function<T>({
  required Widget child,
  bool nestedNavigation,
  bool mergeable,
})>{
  'regular': <T>({
    required child,
    nestedNavigation = false,
    mergeable = true,
  }) =>
      StupidSimpleSheetRoute<T>(
        child: child,
        nestedNavigation: nestedNavigation,
        mergeable: mergeable,
      ),
  'cupertino': <T>({
    required child,
    nestedNavigation = false,
    mergeable = true,
  }) =>
      StupidSimpleCupertinoSheetRoute<T>(
        child: child,
        nestedNavigation: nestedNavigation,
        mergeable: mergeable,
      ),
  'glass': <T>({
    required child,
    nestedNavigation = false,
    mergeable = true,
  }) =>
      StupidSimpleGlassSheetRoute<T>(
        child: child,
        nestedNavigation: nestedNavigation,
        mergeable: mergeable,
      ),
};

class _Page extends StatelessWidget {
  const _Page(this.label, {required this.height, this.onTap});

  final String label;
  final double height;
  final void Function(BuildContext context)? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(context),
      child: SizedBox(
        key: ValueKey(label),
        height: height,
        child: Center(child: Text(label)),
      ),
    );
  }
}

class _RecordingObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late _RecordingObserver observer;

  Future<void> pumpApp(WidgetTester tester) async {
    navigatorKey = GlobalKey<NavigatorState>();
    observer = _RecordingObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('home')),
      ),
    );
  }

  double topOf(WidgetTester tester, String label) =>
      tester.getTopLeft(find.byKey(ValueKey(label))).dy;

  for (final MapEntry(key: type, value: sheet) in _sheetTypes.entries) {
    // Only the regular sheet sizes itself to its content, the Cupertino and
    // glass sheets are always full height.
    final contentSized = type == 'regular';
    group('$type sheet', () {
      testWidgets('stacks sheets without nested navigation', (tester) async {
        await pumpApp(tester);
        navigatorKey.currentState!
            .push(
              sheet<void>(
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(sheet<void>(child: const _Page('B', height: 300)))
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        expect(observer.routes, hasLength(3));
        expect(find.text('B'), findsOneWidget);
      });

      testWidgets('merges a sheet into the host and resizes', (tester) async {
        await pumpApp(tester);
        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;

        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(sheet<void>(child: const _Page('B', height: 400)))
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        final hostTop = topOf(tester, 'A');
        if (contentSized) {
          expect(hostTop, moreOrLessEquals(screenHeight - 200));
        }

        await tester.tap(find.text('A'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        // Still only the host on the root navigator.
        expect(observer.routes, hasLength(2));

        if (contentSized) {
          // Halfway through, the sheet is between both heights.
          final midTop = topOf(tester, 'B');
          expect(midTop, lessThan(hostTop - 1));
          expect(midTop, greaterThan(screenHeight - 400 + 1));
        }

        await tester.pumpAndSettle();
        expect(observer.routes, hasLength(2));
        expect(
          topOf(tester, 'B'),
          moreOrLessEquals(contentSized ? screenHeight - 400 : hostTop),
        );
        // A is kept alive, but not shown anymore.
        expect(find.text('A'), findsNothing);
        expect(find.text('A', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('popping a merged sheet goes back to the host content', (
        tester,
      ) async {
        await pumpApp(tester);
        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        String? result;

        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) async {
                    result = await Navigator.of(context).push(
                      sheet<String>(
                        child: _Page(
                          'B',
                          height: 400,
                          onTap: (context) =>
                              Navigator.of(context).pop('from B'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        final hostTop = topOf(tester, 'A');
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('B'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        if (contentSized) {
          final midTop = topOf(tester, 'A');
          expect(midTop, lessThan(screenHeight - 200 - 1));
          expect(midTop, greaterThan(screenHeight - 400 + 1));
        }

        await tester.pumpAndSettle();
        expect(result, 'from B');
        expect(find.text('B'), findsNothing);
        expect(topOf(tester, 'A'), moreOrLessEquals(hostTop));
        expect(observer.routes, hasLength(2));
      });

      testWidgets('respects mergeable: false', (tester) async {
        await pumpApp(tester);
        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(
                        sheet<void>(
                          mergeable: false,
                          child: const _Page('B', height: 300),
                        ),
                      )
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        expect(observer.routes, hasLength(3));
        expect(find.text('B'), findsOneWidget);
      });

      testWidgets('forwards non-sheet routes to the root navigator', (
        tester,
      ) async {
        await pumpApp(tester);
        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(body: Text('page')),
                        ),
                      )
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        expect(observer.routes, hasLength(3));
        expect(observer.routes.last, isA<MaterialPageRoute<void>>());
      });

      testWidgets('popping the host content pops the whole sheet', (
        tester,
      ) async {
        await pumpApp(tester);
        final result = navigatorKey.currentState!.push(
          sheet<String>(
            nestedNavigation: true,
            child: _Page(
              'A',
              height: 200,
              onTap: (context) {
                expect(Navigator.of(context).canPop(), isTrue);
                Navigator.of(context).pop('from A');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        expect(await result, 'from A');
        expect(observer.routes, hasLength(1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('system back pops merged sheets first', (tester) async {
        await pumpApp(tester);
        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(sheet<void>(child: const _Page('B', height: 400)))
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsNothing);
        expect(observer.routes, hasLength(2));

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);
        expect(observer.routes, hasLength(1));
      });

      testWidgets('dragging down dismisses the whole sheet', (tester) async {
        await pumpApp(tester);
        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(sheet<void>(child: const _Page('B', height: 400)))
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        final before = topOf(tester, 'B');
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('B')),
        );
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(topOf(tester, 'B'), greaterThan(before + 100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('A', skipOffstage: false), findsNothing);
        expect(find.text('B', skipOffstage: false), findsNothing);
        expect(observer.routes, hasLength(1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('PopScope in a merged sheet blocks dismissal', (
        tester,
      ) async {
        await pumpApp(tester);
        var blocked = 0;
        navigatorKey.currentState!
            .push(
              sheet<void>(
                nestedNavigation: true,
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(
                        sheet<void>(
                          child: PopScope<void>(
                            canPop: false,
                            onPopInvokedWithResult: (didPop, _) {
                              if (!didPop) blocked++;
                            },
                            child: const _Page('B', height: 400),
                          ),
                        ),
                      )
                      .ignore(),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        await tester.fling(find.text('B'), const Offset(0, 400), 2000);
        await tester.pumpAndSettle();

        expect(find.text('B'), findsOneWidget);
        expect(blocked, 1);
        expect(observer.routes, hasLength(2));
      });

      testWidgets('controller of host content and merged sheets is the host', (
        tester,
      ) async {
        await pumpApp(tester);
        StupidSimpleSheetController<dynamic>? hostController;
        StupidSimpleSheetController<dynamic>? mergedController;
        final host = sheet<void>(
          nestedNavigation: true,
          child: Builder(
            builder: (context) {
              hostController =
                  StupidSimpleSheetController.maybeOf<void>(context);
              return _Page(
                'A',
                height: 200,
                onTap: (context) => Navigator.of(context).push(
                  sheet<void>(
                    child: Builder(
                      builder: (context) {
                        mergedController =
                            StupidSimpleSheetController.maybeOf<void>(
                          context,
                        );
                        return const _Page('B', height: 400);
                      },
                    ),
                  ),
                ).ignore(),
              );
            },
          ),
        );
        navigatorKey.currentState!.push(host).ignore();
        await tester.pumpAndSettle();
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        expect(hostController, same(host));
        expect(mergedController, isNotNull);
        expect(
          (mergedController! as StupidSimpleSheetTransitionMixin<dynamic>)
              .mergeHost,
          same(host),
        );
      });
    });
  }

  testWidgets('merged sheet with growing content resizes the sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final height = ValueNotifier<double>(300);
    addTearDown(height.dispose);

    navigatorKey.currentState!
        .push(
          StupidSimpleSheetRoute<void>(
            nestedNavigation: true,
            child: _Page(
              'A',
              height: 200,
              onTap: (context) => Navigator.of(context)
                  .push(
                    StupidSimpleSheetRoute<void>(
                      child: ValueListenableBuilder(
                        valueListenable: height,
                        builder: (context, value, _) =>
                            _Page('B', height: value),
                      ),
                    ),
                  )
                  .ignore(),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(topOf(tester, 'B'), moreOrLessEquals(screenHeight - 300));

    height.value = 350;
    await tester.pump();
    expect(topOf(tester, 'B'), moreOrLessEquals(screenHeight - 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SheetNavigator keeps the surrounding SheetBackground in place', (
    tester,
  ) async {
    await pumpApp(tester);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final backgrounds = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox && widget.decoration is ShapeDecoration,
    );

    navigatorKey.currentState!
        .push(
          StupidSimpleSheetRoute<void>(
            child: SheetBackground(
              child: SheetNavigator(
                child: _Page(
                  'A',
                  height: 200,
                  onTap: (context) => Navigator.of(context)
                      .push(
                        StupidSimpleSheetRoute<void>(
                          child: const SheetBackground(
                            child: _Page('B', height: 400),
                          ),
                        ),
                      )
                      .ignore(),
                ),
              ),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(backgrounds, findsOneWidget);

    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // The merged sheet doesn't bring its own background.
    expect(backgrounds, findsOneWidget);

    await tester.pumpAndSettle();
    expect(observer.routes, hasLength(2));
    expect(backgrounds, findsOneWidget);
    expect(topOf(tester, 'B'), moreOrLessEquals(screenHeight - 400));
    expect(
      tester.getTopLeft(backgrounds).dy,
      moreOrLessEquals(screenHeight - 400),
    );
  });

  testWidgets('tapping the barrier dismisses the whole sheet', (tester) async {
    await pumpApp(tester);
    navigatorKey.currentState!
        .push(
          StupidSimpleSheetRoute<void>(
            nestedNavigation: true,
            child: _Page(
              'A',
              height: 200,
              onTap: (context) => Navigator.of(context)
                  .push(
                    StupidSimpleSheetRoute<void>(
                      child: const _Page('B', height: 300),
                    ),
                  )
                  .ignore(),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('B', skipOffstage: false), findsNothing);
    expect(observer.routes, hasLength(1));
  });

  testWidgets('SheetNavigator outside of a sheet just shows its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SheetNavigator(child: Text('plain'))),
    );
    expect(find.text('plain'), findsOneWidget);
    expect(find.byType(Navigator), findsOneWidget);
  });
}
