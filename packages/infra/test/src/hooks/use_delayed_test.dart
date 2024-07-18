import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infra/src/hooks/use_delayed.dart';
import 'package:infra_test/infra_test.dart';

void main() {
  group('useDelayed', () {
    setUp(() {});

    Widget build({required bool Function() hookCall}) {
      return HookBuilder(
        builder: (context) {
          final value = hookCall();
          return SizedBox(key: ValueKey(value));
        },
      );
    }

    testWidgets('returns before until delay has passed', (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey(false)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
    });

    testWidgets('restarts when delay is changed', (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 2),
            before: false,
            after: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey(false)), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
    });

    testWidgets('restarts when values are changed', (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: true,
            after: false,
          ),
        ),
      );
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(false)), findsOneWidget);
    });

    testWidgets('restarts when keys are changed', (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
            keys: [1],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
            keys: [2],
          ),
        ),
      );
      expect(find.byKey(const ValueKey(false)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
    });

    testWidgets('returns after when delay is 0', (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: Duration.zero,
            before: false,
            after: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
    });

    testWidgets('starts with after when startDone is true', (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
            startDone: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
    });

    testWidgets('restarts when startDone is true and keys change',
        (tester) async {
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
            startDone: true,
            keys: [1],
          ),
        ),
      );
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
      await tester.pumpWidget(
        build(
          hookCall: () => useDelayed(
            delay: const Duration(seconds: 1),
            before: false,
            after: true,
            startDone: true,
            keys: [2],
          ),
        ),
      );
      expect(find.byKey(const ValueKey(false)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(true)), findsOneWidget);
    });
  });
}
