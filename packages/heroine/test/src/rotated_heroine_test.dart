import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';

void main() {
  group('Heroine under a rotated ancestor', () {
    const tag = 'photo';
    const tilt = 0.3;
    const heroSize = 80.0;

    // Settles much faster than the route transition, so sampling near the
    // end of the route reads the flight's settled *target* rather than a
    // point mid-air.
    const motion = CupertinoMotion.smooth(
      duration: Duration(milliseconds: 60),
    );

    Widget build() => MaterialApp(
          navigatorObservers: [HeroineController()],
          home: Scaffold(
            body: Center(
              child: Transform.rotate(
                angle: tilt,
                child: const Heroine(
                  tag: tag,
                  motion: motion,
                  child: SizedBox.square(dimension: heroSize),
                ),
              ),
            ),
          ),
        );

    Widget page2() => const Scaffold(
          body: Center(
            child: Heroine(
              tag: tag,
              motion: motion,
              child: SizedBox.square(dimension: 300),
            ),
          ),
        );

    testWidgets(
        'a pop flies home to the true rect and tilt, '
        'not the axis-aligned bounding box', (tester) async {
      await tester.pumpWidget(build());

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) => page2(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      navigator.pop();
      await tester.pump();
      // Frame by frame to just shy of the route completing: the overlay is
      // still up, and the fast spring has already settled at its target.
      for (var elapsed = 0; elapsed < 280; elapsed += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // An 80×80 hero rotated by 0.3 rad has a ~100-wide axis-aligned
      // bounding box; the flight must aim at the hero's own square instead.
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.width, closeTo(heroSize, 1));
      expect(positioned.height, closeTo(heroSize, 1));

      // And the shuttle must arrive carrying the destination's resting tilt.
      final rotate = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(Positioned),
              matching: find.byType(Transform),
            )
            .first,
      );
      final transform = rotate.transform;
      expect(
        math.atan2(transform.entry(1, 0), transform.entry(0, 0)),
        closeTo(tilt, 0.01),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Heroine)),
        const Size.square(heroSize),
      );
    });
  });
}
