import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infra/src/hooks/use_tween_animation.dart';
import 'package:infra_test/infra_test.dart';

class _MockWidget extends HookConsumerWidget {
  const _MockWidget({
    this.tween,
    this.curve = Curves.linear,
  });

  final Tween<double>? tween;
  final Curve curve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = useTweenAnimation<double>(
      tween ?? Tween(begin: 0, end: 1),
      curve: curve,
    );
    return Text(value.toStringAsFixed(2));
  }
}

void main() {
  group('useTweenAnimation', () {
    testWidgets(
      'animates from start to target value with default duration',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: _MockWidget(),
          ),
        );
        expect(find.text("0.00"), findsOneWidget);
        await tester.pump(kThemeAnimationDuration * 0.5);
        expect(find.text("0.50"), findsOneWidget);
        await tester.pump(kThemeAnimationDuration * 0.5);
        expect(find.text("1.00"), findsOneWidget);
      },
    );

    testWidgets(
      'animates with Curve ',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: _MockWidget(
              curve: Curves.ease,
            ),
          ),
        );
        expect(find.text("0.00"), findsOneWidget);
        await tester.pump(kThemeAnimationDuration * 0.5);
        expect(
          find.text(Curves.ease.transform(0.5).toStringAsFixed(2)),
          findsOneWidget,
        );
        await tester.pump(kThemeAnimationDuration * 0.5);
        expect(find.text("1.00"), findsOneWidget);
      },
    );

    testWidgets(
      'animates Changes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: _MockWidget(
              tween: Tween(begin: 0, end: 0),
            ),
          ),
        );
        expect(find.text("0.00"), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text("0.00"), findsOneWidget);
        await tester.pumpWidget(
          MaterialApp(
            home: _MockWidget(
              tween: Tween(begin: 1, end: 1),
            ),
          ),
        );
        expect(find.text("0.00"), findsOneWidget);
        await tester.pump(kThemeAnimationDuration * 0.5);
        expect(find.text("0.50"), findsOneWidget);
        await tester.pump(kThemeAnimationDuration * 0.5);
        expect(find.text("1.00"), findsOneWidget);
      },
    );
  });
}
