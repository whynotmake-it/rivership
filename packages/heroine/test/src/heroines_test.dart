import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';
import 'package:springster/springster.dart';

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
                      motion: motion ?? const SpringMotion(Spring()),
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
      tester
          .push(buildPage2(motion: const SpringMotion(Spring.bouncy)))
          .ignore();

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
      tester
          .push(buildPage2(motion: const SpringMotion(Spring.bouncy)))
          .ignore();

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
