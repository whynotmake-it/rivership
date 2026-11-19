import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';

void main() {
  for (final flutterHeroController in ['none', 'observer', 'scope']) {
    testWidgets(
      'does not paint the destination before flight '
      '(Flutter HeroController: $flutterHeroController)',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final destinationKey = GlobalKey();
        const shuttleKey = ValueKey('shuttle');
        final paintedSizes = <Size>[];

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            // MaterialApp's implicit HeroController otherwise hides the bug.
            builder: flutterHeroController == 'scope'
                ? null
                : (context, child) => HeroControllerScope.none(child: child!),
            navigatorObservers: [
              HeroineController(),
              if (flutterHeroController == 'observer') HeroController(),
            ],
            home: const ColoredBox(
              color: Colors.black,
              child: Align(
                alignment: Alignment.topLeft,
                child: Heroine(
                  tag: 'detail',
                  child: SizedBox.square(
                    dimension: 80,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        );

        final route = PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => Heroine(
            tag: 'detail',
            flightShuttleBuilder: HeroineShuttleBuilder.fromHero(
              flightShuttleBuilder: (_, __, ___, ____, _____) =>
                  const ColoredBox(key: shuttleKey, color: Colors.green),
            ),
            child: CustomPaint(
              key: destinationKey,
              painter: _PaintRecorder(paintedSizes),
              child: const SizedBox.expand(),
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        );
        unawaited(navigatorKey.currentState!.push(route));

        // Exactly the layout frame: no settling or screenshot helper pumps.
        await tester.pump();
        expect(
          tester.getSize(find.byKey(destinationKey, skipOffstage: false)),
          const Size(800, 600),
        );
        expect(
          paintedSizes,
          isEmpty,
          reason: 'The destination must not paint before the post-frame flight '
              'starts.',
        );
        expect(route.offstage, isFalse);

        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byKey(shuttleKey), findsOneWidget);
        expect(tester.getSize(find.byKey(shuttleKey)).width, lessThan(800));

        await tester.pumpAndSettle();
        expect(find.byKey(shuttleKey), findsNothing);
        expect(paintedSizes.last, const Size(800, 600));
        expect(route.offstage, isFalse);
        expect(tester.takeException(), isNull);

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('restores a pushed page with no matching heroines',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final paintedSizes = <Size>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => HeroControllerScope.none(child: child!),
        navigatorObservers: [HeroineController()],
        home: const SizedBox.expand(),
      ),
    );
    final route = PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => CustomPaint(
        painter: _PaintRecorder(paintedSizes),
        child: const SizedBox.expand(),
      ),
    );
    unawaited(navigatorKey.currentState!.push(route));

    await tester.pump();
    expect(paintedSizes, isEmpty);
    expect(route.offstage, isFalse);

    await tester.pump();
    expect(paintedSizes, [const Size(800, 600)]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _PaintRecorder extends CustomPainter {
  _PaintRecorder(this.paintedSizes);

  final List<Size> paintedSizes;

  @override
  void paint(Canvas canvas, Size size) {
    paintedSizes.add(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_PaintRecorder oldDelegate) => false;
}
