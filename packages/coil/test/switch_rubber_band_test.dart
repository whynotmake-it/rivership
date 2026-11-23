import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
    child: Center(child: child),
  ),
);

void main() {
  testWidgets('a switch dragged past its end stretches ever more softly, '
      'never stopping and never past a limit', (tester) async {
    for (final value in [false, true]) {
      await tester.pumpWidget(
        _app(CoilSwitch(value: value, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(CoilSwitch));
      // Pulling the thumb against the end it rests at: left when off,
      // right when on.
      final direction = value ? 1.0 : -1.0;
      final thumbAtEnd = Offset(
        value ? rect.right - 10 : rect.left + 10,
        rect.center.dy,
      );

      double stretch() {
        final track = tester.widget<Transform>(
          find.descendant(
            of: find.byType(CoilSwitch),
            matching: find.byWidgetPredicate(
              (widget) => widget is Transform && widget.child is Container,
            ),
          ),
        );
        return track.transform.storage[0];
      }

      final gesture = await tester.startGesture(thumbAtEnd);
      // Past the touch slop, so the thumb follows.
      await gesture.moveBy(Offset(direction * (kTouchSlop * 2), 0));
      await tester.pump();
      final resting = stretch();

      // Growing overshoots, as a finger could drag them.
      final stretches = <double>[];
      var dragged = 0.0;
      for (final target in [10.0, 40.0, 160.0, 640.0]) {
        await gesture.moveBy(Offset(direction * (target - dragged), 0));
        await tester.pump();
        dragged = target;
        stretches.add(stretch());
      }

      expect(stretches.first, greaterThan(resting));
      for (var i = 1; i < stretches.length; i++) {
        // It never stops growing...
        expect(stretches[i], greaterThan(stretches[i - 1]));
      }
      for (var i = 2; i < stretches.length; i++) {
        // ...but each step adds less than the one before.
        expect(
          stretches[i] - stretches[i - 1],
          lessThan(stretches[i - 1] - stretches[i - 2]),
        );
      }
      // And it never passes the limit: under 4 % wider.
      expect(stretches.last, lessThan(1.04));

      await gesture.up();
      await tester.pumpAndSettle();
      // Let go, it settles back to its resting shape.
      expect(stretch(), closeTo(1, 1e-6));
    }
  });
}
