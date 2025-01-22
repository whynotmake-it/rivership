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

    const frameSize = Size(400, padding + heroSize + padding);

    Widget build({bool isHeroine = true}) {
      final child = Container(color: Colors.red);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: [HeroineController()],
        home: Scaffold(
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
      Spring? spring,
    }) {
      final child = Container(color: Colors.green);
      return Scaffold(
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
      final animationSheet = AnimationSheetBuilder(
        frameSize: frameSize,
      );

      final widget = animationSheet.record(build());

      await tester.pumpWidget(widget);
      // push page 2
      final navigator = Navigator.of(tester.element(find.byType(Container)));

      expect(navigator.canPop(), isFalse);

      navigator
          .push(
            MaterialPageRoute<bool>(
              builder: (context) => buildPage2(spring: Spring.bouncy),
            ),
          )
          .ignore();

      await tester.pumpFrames(widget, const Duration(milliseconds: 700));

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/heroine_default_animation.png'),
      );
    });

    testWidgets('redirected animation matches golden', (tester) async {
      final animationSheet = AnimationSheetBuilder(
        frameSize: frameSize,
      );

      final widget = animationSheet.record(build());

      await tester.pumpWidget(widget);
      // push page 2
      final navigator = Navigator.of(tester.element(find.byType(Container)));

      expect(navigator.canPop(), isFalse);

      navigator
          .push(
            MaterialPageRoute<bool>(
              builder: (context) => buildPage2(spring: Spring.bouncy),
            ),
          )
          .ignore();

      await tester.pumpFrames(widget, const Duration(milliseconds: 150));

      navigator.pop();

      await tester.pumpFrames(widget, const Duration(milliseconds: 200));

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/heroine_redirected_animation.png'),
      );
    });
  });
}
