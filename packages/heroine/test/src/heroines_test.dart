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

    const padding = 10.0;
    const heroSize = 100.0;

    const frameSize = Size(800, padding + heroSize + padding);

    const pumpDuration = Duration(milliseconds: 700);

    late AnimationSheetBuilder animationSheet;

    setUp(() {
      animationSheet = AnimationSheetBuilder(frameSize: frameSize);
    });

    Widget build({bool isHeroine = true}) {
      final child = Container(color: Colors.red);
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
      Spring? spring,
    }) {
      final child = Container(color: Colors.green);
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
                      spring: spring ?? const Spring(),
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
      tester.push(buildPage2(spring: Spring.bouncy)).ignore();

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
      tester.push(buildPage2(spring: Spring.bouncy)).ignore();

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
