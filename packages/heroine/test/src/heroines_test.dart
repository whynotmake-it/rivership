import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';

void main() {
  group('HeroineController', () {
    test('can be instantiated', () {
      expect(HeroineController(), isA<NavigatorObserver>());
    });
  });

  group('Heroine', () {
    const tag = true;
    const nestedTag = 'nested';

    const padding = 10.0;
    const heroSize = 100.0;

    const frameSize = Size(800, padding + heroSize + padding);

    const pumpDuration = Duration(milliseconds: 700);

    late AnimationSheetBuilder animationSheet;

    setUp(() {
      animationSheet = AnimationSheetBuilder(frameSize: frameSize);
    });

    Widget build({
      bool isHeroine = true,
      bool hasNestedHeroine = false,
    }) {
      final nestedChild = Container(color: Colors.red);
      final child = hasNestedHeroine
          ? Heroine(
              tag: nestedTag,
              child: nestedChild,
            )
          : nestedChild;

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: [HeroineController()],
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(padding),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.square(
                dimension: heroSize,
                child: isHeroine
                    ? Heroine(
                        tag: tag,
                        child: child,
                      )
                    : child,
              ),
            ),
          ),
        ),
      );
    }

    Widget buildPage2({
      bool isHeroine = true,
      HeroineShuttleBuilder? shuttleBuilder,
      Motion? motion,
      bool hasNestedHeroine = false,
    }) {
      final nestedChild = Container(color: Colors.green);
      final child = hasNestedHeroine
          ? Heroine(
              tag: nestedTag,
              child: nestedChild,
            )
          : nestedChild;
      return Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(padding),
          child: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox.square(
              dimension: heroSize,
              child: isHeroine
                  ? Heroine(
                      tag: tag,
                      motion: motion ?? const CupertinoMotion.smooth(),
                      flightShuttleBuilder:
                          shuttleBuilder ?? const FadeShuttleBuilder(),
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      );
    }

    testWidgets('normal build matches golden', (tester) async {
      await tester.pumpWidget(build());

      expect(find.byType(MaterialApp), matchesGoldenFile('golden/basic.png'));
    });

    testWidgets('wrapped passes the same constraints', (tester) async {
      await tester.pumpWidget(build());
      final boxWithHeroine =
          tester.renderObject(find.byType(Container)) as RenderBox;

      await tester.pumpWidget(build(isHeroine: false));
      final boxWithoutHeroine =
          tester.renderObject(find.byType(Container)) as RenderBox;

      expect(boxWithHeroine.size, boxWithoutHeroine.size);
      expect(boxWithHeroine.constraints, boxWithoutHeroine.constraints);
    });

    testWidgets('default animation matches golden', (tester) async {
      final widget = animationSheet.record(build());

      await tester.pumpWidget(widget);

      // push page 2
      tester.push(buildPage2(motion: const CupertinoMotion.bouncy())).ignore();

      await tester.pumpFrames(widget, pumpDuration);

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/heroine_default_animation.png'),
      );
    });

    testWidgets('redirected animation matches golden', (tester) async {
      final widget = animationSheet.record(build());

      await tester.pumpWidget(widget);
      // push page 2
      tester.push(buildPage2(motion: const CupertinoMotion.bouncy())).ignore();

      await tester.pumpFrames(widget, pumpDuration * 0.2);

      tester.pop();

      await tester.pumpFrames(widget, pumpDuration * 0.8);

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/heroine_redirected_animation.png'),
      );
    });

    testWidgets('flip animation matches golden', (tester) async {
      final widget = animationSheet.record(build());

      await tester.pumpWidget(widget);

      tester
          .push(buildPage2(shuttleBuilder: const FlipShuttleBuilder()))
          .ignore();

      await tester.pumpFrames(widget, pumpDuration);

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/heroine_flip_animation.png'),
      );
    });

    testWidgets('flip + fade animation matches golden', (tester) async {
      final shuttle =
          const FlipShuttleBuilder().chain(const FadeThroughShuttleBuilder());

      final widget = animationSheet.record(build());

      await tester.pumpWidget(widget);

      tester.push(buildPage2(shuttleBuilder: shuttle)).ignore();

      await tester.pumpFrames(widget, pumpDuration * .5);

      tester.pop();

      await tester.pumpFrames(widget, pumpDuration * .5);

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/heroine_flip_and_fade_through.png'),
      );
    });

    group('nested heroines', () {
      testWidgets(
        'are allowed if the nested child doesn not fly',
        (tester) async {
          await tester.pumpWidget(build(hasNestedHeroine: true));

          expect(find.heroineWithTag(tag), findsOneWidget);
          expect(find.heroineWithTag(nestedTag), findsOneWidget);

          await tester.pumpAndSettle();

          tester.push(buildPage2()).ignore();

          await tester.pumpAndSettle();

          expect(find.heroineWithTag(tag), findsOneWidget);
          expect(find.heroineWithTag(nestedTag), findsNothing);
        },
      );

      testWidgets(
        'throws assertion error if nested heroine wants to fly',
        (tester) async {
          await TestAsyncUtils.guard(() async {
            await tester.pumpWidget(build(hasNestedHeroine: true));

            expect(find.heroineWithTag(tag), findsOneWidget);
            expect(find.heroineWithTag(nestedTag), findsOneWidget);

            await tester.pumpAndSettle();

            tester.push(buildPage2(hasNestedHeroine: true)).ignore();

            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isA<AssertionError>().having(
                (e) => e.message,
                'message',
                contains('nested'),
              ),
            );
          });
        },
      );
    });

    testWidgets(
      'overlay stays visible until route transition completes even when '
      'heroines are in same position',
      (tester) async {
        // This test reproduces a bug where if from and to heroines are in
        // the exact same position, the animation completes immediately,
        // causing the overlay entry to be removed before the route transition
        // finishes.
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorObservers: [HeroineController()],
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Padding(
                padding: const EdgeInsets.all(padding),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox.square(
                    dimension: heroSize,
                    child: Heroine(
                      tag: tag,
                      child: Container(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialHeroineCount = find.heroineWithTag(tag).evaluate().length;
        expect(initialHeroineCount, 1);

        // Navigate to a page where the heroine is in the SAME position
        tester
            .push(
              Scaffold(
                backgroundColor: Colors.black,
                body: Padding(
                  padding: const EdgeInsets.all(padding),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.square(
                      dimension: heroSize,
                      child: Heroine(
                        tag: tag,
                        child: Container(color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .ignore();

        // Pump one frame to start the transition
        await tester.pump();
        await tester.pump();

        // During the transition, we should have at least 3 heroines:
        // 1. fromHero (offstage)
        // 2. toHero (offstage)
        // 3. overlay heroine (visible in flight)
        final heroineCountDuringTransition1 =
            find.heroineWithTag(tag).evaluate().length;
        expect(
          heroineCountDuringTransition1,
          greaterThanOrEqualTo(3),
          reason: 'Should have from, to, and overlay heroines during flight',
        );

        // Pump halfway through the default transition duration (300ms)
        await tester.pump(const Duration(milliseconds: 150));

        // Overlay heroine should still be present
        final heroineCountDuringTransition2 =
            find.heroineWithTag(tag).evaluate().length;
        expect(
          heroineCountDuringTransition2,
          greaterThanOrEqualTo(3),
          reason: 'Overlay should remain visible during route transition',
        );

        // Complete the route transition
        await tester.pumpAndSettle();

        // After route transition completes, only the destination heroine
        // remains
        expect(find.heroineWithTag(tag).evaluate().length, 1);
      },
    );

    group('z-index', () {
      testWidgets('matches golden', (tester) async {
        final heroines = <Heroine>[
          // Heroine with z-index 10
          Heroine(
            tag: 'heroine-z10',
            zIndex: 10,
            flightShuttleBuilder: const SingleShuttleBuilder(),
            child: Container(
              key: const ValueKey(10),
              width: 50,
              height: 50,
              color: Colors.red,
            ),
          ),
          // Heroine with z-index 1
          Heroine(
            tag: 'heroine-z1',
            zIndex: 0,
            flightShuttleBuilder: const SingleShuttleBuilder(),
            child: Container(
              key: const ValueKey(0),
              width: 50,
              height: 50,
              color: Colors.blue,
            ),
          ),
          // Heroine with no z-index
          Heroine(
            tag: 'heroine-no-z',
            flightShuttleBuilder: const SingleShuttleBuilder(),
            child: Container(
              key: const ValueKey(null),
              width: 50,
              height: 50,
              color: Colors.green,
            ),
          ),
          // Heroine with z-index 5
          Heroine(
            tag: 'heroine-z5',
            flightShuttleBuilder: const SingleShuttleBuilder(),
            zIndex: 5,
            child: Container(
              key: const ValueKey(5),
              width: 50,
              height: 50,
              color: Colors.yellow,
            ),
          ),
        ];
        // Create a simple test with multiple heroines with different z-index
        // values
        final app = MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorObservers: [HeroineController()],
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Row(
              spacing: 20,
              children: [
                ...heroines,
              ],
            ),
          ),
        );

        final widget = animationSheet.record(app);
        await tester.pumpWidget(widget);

        // Verify all heroines are present on the first page
        expect(find.byType(Heroine), findsNWidgets(4));
        expect(find.byKey(const ValueKey(10)), findsOneWidget);
        expect(find.byKey(const ValueKey(0)), findsOneWidget);
        expect(find.byKey(const ValueKey(null)), findsOneWidget);
        expect(find.byKey(const ValueKey(5)), findsOneWidget);

        // Navigate to trigger heroine animations
        tester
            .push(
              Scaffold(
                backgroundColor: Colors.white,
                body: Row(
                  spacing: 20,
                  children: [
                    // Corresponding heroines on second page
                    ...heroines.reversed,
                  ],
                ),
              ),
            )
            .ignore();

        await tester.pumpFrames(widget, pumpDuration * 0.5);

        // After animation, we should have 4 heroines on the second page
        expect(find.byType(Heroine), findsNWidgets(4));
        expect(find.byKey(const ValueKey(10)), findsOneWidget);
        expect(find.byKey(const ValueKey(0)), findsOneWidget);
        expect(find.byKey(const ValueKey(null)), findsOneWidget);
        expect(find.byKey(const ValueKey(5)), findsOneWidget);

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/z_index_heroine_in_flight.png'),
        );
      });

      testWidgets('z-index property is accessible', (tester) async {
        const heroine1 = Heroine(
          tag: 'test1',
          zIndex: 5,
          child: Text('Test'),
        );

        const heroine2 = Heroine(
          tag: 'test2',
          child: Text('Test'),
        );

        expect(heroine1.zIndex, equals(5));
        expect(heroine2.zIndex, isNull);
      });
    });
  });
}

extension WidgetTesterX on WidgetTester {
  Future<void> push(Widget widget) async {
    final navigator = state<NavigatorState>(find.byType(Navigator));

    await navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => widget,
      ),
    );
  }

  void pop() {
    state<NavigatorState>(find.byType(Navigator)).pop();
  }
}

extension FindersX on CommonFinders {
  Finder heroineWithTag(Object tag) {
    return byWidgetPredicate((w) {
      if (w is Heroine) {
        return w.tag == tag;
      }

      return false;
    });
  }
}
