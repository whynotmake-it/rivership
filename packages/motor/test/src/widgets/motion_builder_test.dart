import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

/// Builds one builder variant that reports to [harness] on every build.
///
/// Two-dimensional variants animate `(x, -2 * x)` for a scalar `x`, so each
/// dimension moves a different way.
typedef _BuildVariant = Widget Function(
  _Harness harness,
  ({double value, double? from, bool active, Motion motion}) config,
);

/// Pumps one builder variant and records what it passed to its `builder`.
class _Harness {
  _Harness(this.tester, this.name, this.build);

  final WidgetTester tester;
  final String name;
  final _BuildVariant build;

  List<double> value = const [];
  List<double>? velocity;

  /// The value each dimension should have for the scalar [x].
  List<double> expected(double x) => [x, -2 * x].take(value.length).toList();

  Future<void> pump(
    double to, {
    double? from,
    bool active = true,
    Motion motion = const CupertinoMotion.smooth(),
  }) =>
      tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey(name),
          child: build(
            this,
            (value: to, from: from, active: active, motion: motion),
          ),
        ),
      );
}

(double, double) _spread(double x) => (x, -2 * x);

MotionConverter<(double, double)> _pairConverter() => MotionConverter.custom(
      normalize: (value) => [value.$1, value.$2],
      denormalize: (values) => (values[0], values[1]),
    );

final _variants = <(String, _BuildVariant)>[
  (
    'SingleMotionBuilder',
    (harness, c) => SingleMotionBuilder(
          value: c.value,
          from: c.from,
          active: c.active,
          motion: c.motion,
          builder: (context, value, child) {
            harness.value = [value];
            return const SizedBox();
          },
        ),
  ),
  (
    'MotionBuilder',
    (harness, c) => MotionBuilder<(double, double)>(
          value: _spread(c.value),
          from: c.from == null ? null : _spread(c.from!),
          active: c.active,
          motion: c.motion,
          converter: _pairConverter(),
          builder: (context, value, child) {
            harness.value = [value.$1, value.$2];
            return const SizedBox();
          },
        ),
  ),
  (
    'SingleVelocityMotionBuilder',
    (harness, c) => SingleVelocityMotionBuilder(
          value: c.value,
          from: c.from,
          active: c.active,
          motion: c.motion,
          builder: (context, value, velocity, child) {
            harness
              ..value = [value]
              ..velocity = [velocity];
            return const SizedBox();
          },
        ),
  ),
  (
    'VelocityMotionBuilder',
    (harness, c) => VelocityMotionBuilder<(double, double)>(
          value: _spread(c.value),
          from: c.from == null ? null : _spread(c.from!),
          active: c.active,
          motion: c.motion,
          converter: _pairConverter(),
          builder: (context, value, velocity, child) {
            harness
              ..value = [value.$1, value.$2]
              ..velocity = [velocity.$1, velocity.$2];
            return const SizedBox();
          },
        ),
  ),
];

void main() {
  group('motion builders', () {
    Iterable<_Harness> harnesses(WidgetTester tester) =>
        _variants.map((v) => _Harness(tester, v.$1, v.$2));

    testWidgets('build at rest with the initial value', (tester) async {
      for (final h in harnesses(tester)) {
        await h.pump(10);
        expect(h.value, h.expected(10), reason: h.name);
        if (h.velocity case final velocity?) {
          expect(velocity, everyElement(0), reason: h.name);
        }
      }
    });

    testWidgets('animate every dimension toward a new value', (tester) async {
      for (final h in harnesses(tester)) {
        await h.pump(0);
        expect(h.value, h.expected(0), reason: h.name);

        await h.pump(100);
        await tester.pump(const Duration(milliseconds: 16));
        final target = h.expected(100);
        for (var i = 0; i < target.length; i++) {
          final towardTarget = target[i] > 0
              ? inExclusiveRange(0, target[i])
              : inExclusiveRange(target[i], 0);
          expect(h.value[i], towardTarget, reason: '${h.name}[$i]');
          if (h.velocity case final velocity?) {
            expect(velocity[i].sign, target[i].sign, reason: '${h.name}[$i]');
          }
        }
        await tester.pumpAndSettle();
      }
    });

    testWidgets('start at from and animate to the value', (tester) async {
      for (final h in harnesses(tester)) {
        await h.pump(100, from: 0);
        expect(h.value, h.expected(0), reason: h.name);

        await tester.pumpAndSettle();
        final target = h.expected(100);
        for (var i = 0; i < target.length; i++) {
          expect(h.value[i], closeTo(target[i], error), reason: h.name);
        }
      }
    });

    testWidgets('stay at from while inactive', (tester) async {
      for (final h in harnesses(tester)) {
        await h.pump(100, from: 0, active: false);
        await tester.pumpAndSettle();
        expect(h.value, h.expected(0), reason: h.name);
      }
    });

    testWidgets('jump to a new value while inactive', (tester) async {
      for (final h in harnesses(tester)) {
        await h.pump(0, active: false);
        if (h.velocity case final velocity?) {
          expect(velocity, everyElement(0), reason: h.name);
        }

        await h.pump(100, active: false);
        expect(h.value, h.expected(100), reason: h.name);
      }
    });

    testWidgets('jump to the target when turned inactive mid-animation',
        (tester) async {
      const linear = Motion.linear(Duration(milliseconds: 100));
      for (final h in harnesses(tester)) {
        await h.pump(100, from: 0, motion: linear);
        await tester.pump(const Duration(milliseconds: 50));
        final halfway = h.expected(50);
        for (var i = 0; i < halfway.length; i++) {
          expect(h.value[i], closeTo(halfway[i], error), reason: h.name);
        }

        await h.pump(100, from: 0, active: false, motion: linear);
        await tester.pump();
        expect(h.value, h.expected(100), reason: h.name);
        expect(tester.hasRunningAnimations, isFalse, reason: h.name);
      }
    });

    testWidgets('follow the same bouncy trajectory in every variant',
        (tester) async {
      final trajectories = <String, List<double>>{};
      for (final h in harnesses(tester)) {
        await h.pump(170, from: 10, motion: const CupertinoMotion.bouncy());
        final trajectory = trajectories[h.name] = [h.value.first];
        for (var t = 0; t < 2000; t += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          trajectory.add(h.value.first);
        }
        expect(trajectory.last, closeTo(170, error), reason: h.name);
      }

      final reference = trajectories.values.first;
      expect(reference.reduce((a, b) => a > b ? a : b), greaterThan(170));
      for (final MapEntry(key: name, value: trajectory)
          in trajectories.entries) {
        expect(trajectory, orderedEquals(reference), reason: name);
      }
    });
  });

  testWidgets('MotionBuilder leaves a dimension that starts at its target',
      (tester) async {
    (double, double)? captured;
    await tester.pumpWidget(
      MotionBuilder(
        value: (0.0, 0.0),
        from: (0.0, 100.0),
        motion: const CupertinoMotion.smooth(),
        converter: _pairConverter(),
        builder: (context, value, child) {
          captured = value;
          return const SizedBox();
        },
      ),
    );
    expect(captured, (0.0, 100.0));

    await tester.pumpAndSettle();
    expect(captured?.$1, 0.0);
    expect(captured?.$2, closeTo(0.0, error));
  });
}
