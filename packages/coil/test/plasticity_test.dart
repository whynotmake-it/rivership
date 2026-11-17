import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [input]'s field is drawn with a lit edge.
bool _lit(WidgetTester tester, Finder input) => find
    .descendant(
      of: input,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is CoilReliefBorder,
      ),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    CoilTheme(
      data: CoilThemeData.light.copyWith(plasticity: CoilPlasticity.subtle),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );

  group('plasticity on surfaces', () {
    testWidgets('controls on the page are lit', (tester) async {
      await pump(tester, const CoilInput(key: Key('field')));
      expect(_lit(tester, find.byKey(const Key('field'))), isTrue);
    });

    testWidgets('controls on an elevated surface are flat', (tester) async {
      late CoilPlasticity inside;
      await pump(
        tester,
        CoilSurface(
          offset: CoilSurface.popoverOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoilInput(key: Key('field')),
              Builder(
                builder: (context) {
                  inside = CoilTheme.of(context).plasticity;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      expect(inside, CoilPlasticity.flat);
      expect(_lit(tester, find.byKey(const Key('field'))), isFalse);
    });

    testWidgets('a card scope flattens its content too', (tester) async {
      await pump(
        tester,
        const CoilSurface.scope(
          offset: 1,
          child: CoilInput(key: Key('field')),
        ),
      );
      expect(_lit(tester, find.byKey(const Key('field'))), isFalse);
    });

    testWidgets('a style override still lights a control on a surface', (
      tester,
    ) async {
      await pump(
        tester,
        const CoilSurface(
          offset: CoilSurface.popoverOffset,
          child: CoilInput(
            key: Key('field'),
            style: CoilInputStyle(plasticity: CoilPlasticity.subtle),
          ),
        ),
      );
      expect(_lit(tester, find.byKey(const Key('field'))), isTrue);
    });

    testWidgets('surfaces and cards are never lit', (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            CoilSurface(
              key: Key('surface'),
              offset: CoilSurface.popoverOffset,
              child: SizedBox(height: 20),
            ),
            CoilCard(key: Key('card'), title: Text('Card')),
          ],
        ),
      );
      for (final key in ['surface', 'card']) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is ShapeDecoration &&
                  (w.decoration as ShapeDecoration).shape is CoilReliefBorder,
            ),
          ),
          findsNothing,
          reason: key,
        );
      }
    });

    testWidgets('flattenAbove moves the cutoff; 1 is the page', (
      tester,
    ) async {
      Future<void> pumpAt(int flattenAbove) => tester.pumpWidget(
        CoilTheme(
          data: CoilThemeData.light.copyWith(
            plasticity: CoilPlasticity.subtle.copyWith(
              flattenAbove: flattenAbove,
            ),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                // Level 3: on a popover opened from the page.
                CoilSurface(
                  offset: 2,
                  child: CoilInput(key: Key('three')),
                ),
                // Level 4.
                CoilSurface(
                  offset: 3,
                  child: CoilInput(key: Key('four')),
                ),
              ],
            ),
          ),
        ),
      );

      await pumpAt(3);
      expect(_lit(tester, find.byKey(const Key('three'))), isTrue);
      expect(_lit(tester, find.byKey(const Key('four'))), isFalse);

      expect(CoilPlasticity.subtle.flattenAbove, 1);
      await pumpAt(1);
      expect(_lit(tester, find.byKey(const Key('three'))), isFalse);
      expect(_lit(tester, find.byKey(const Key('four'))), isFalse);
    });

    testWidgets('an unelevated scope lights a subtree again', (tester) async {
      await pump(
        tester,
        const CoilSurface(
          offset: CoilSurface.popoverOffset,
          child: CoilPlasticityScope(
            elevated: false,
            child: CoilInput(key: Key('field')),
          ),
        ),
      );
      expect(_lit(tester, find.byKey(const Key('field'))), isTrue);
    });
  });

  test('roles scale and switch off lighting per role', () {
    const p = CoilPlasticity.subtle;
    expect(p.resolve(CoilReliefRole.track, Brightness.light), isNull);
    expect(p.resolve(CoilReliefRole.quiet, Brightness.dark), isNull);
    expect(p.resolve(CoilReliefRole.raised, Brightness.light), isNotNull);
    expect(CoilPlasticity.flat.resolve(.raised, Brightness.light), isNull);
    expect(
      p.resolve(CoilReliefRole.raised, Brightness.light, enabled: false),
      isNull,
    );
  });

  group('CoilRelief.decorate', () {
    final relief = const CoilPlasticity(
      amount: 1,
    ).resolve(.raised, Brightness.light)!;
    const plain = ShapeDecoration(
      color: Color(0xFFFFFFFF),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );

    test('is idempotent: a lit shape is lit once', () {
      final once = CoilRelief.decorate(plain, relief);
      final twice = CoilRelief.decorate(once, relief);
      expect(twice.shape, once.shape);
      final border = twice.shape as CoilReliefBorder;
      expect(border.shape, plain.shape);
    });

    test('a second relief replaces the first', () {
      final other = CoilPlasticity.subtle.resolve(.raised, Brightness.dark)!;
      final lit = CoilRelief.decorate(
        CoilRelief.decorate(plain, relief),
        other,
      );
      expect((lit.shape as CoilReliefBorder).relief, other);
    });

    test('asserts on shapes that are not superellipses', () {
      expect(
        () => CoilRelief.decorate(
          const ShapeDecoration(shape: StadiumBorder()),
          relief,
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('RoundedSuperellipseBorder'),
          ),
        ),
      );
    });

    test('tweens keep their corners and fade the light', () {
      final lit = CoilRelief.decorate(plain, relief);
      const wide = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      );
      for (final (from, to) in [
        (plain.shape, lit.shape),
        (lit.shape, plain.shape),
        (
          lit.shape,
          CoilRelief.decorate(const ShapeDecoration(shape: wide), relief).shape,
        ),
      ]) {
        final mid = ShapeBorder.lerp(from, to, 0.5);
        expect(mid, isA<CoilReliefBorder>(), reason: '$from -> $to');
        final shape = (mid! as CoilReliefBorder).shape;
        // No collapse through a scaled-down shape: the radius stays in
        // between the ends.
        final radius = (shape.borderRadius as BorderRadius).topLeft.x;
        expect(radius, inInclusiveRange(8, 12));
      }
      // Half way from unlit, the light is half on.
      final half =
          (ShapeBorder.lerp(plain.shape, lit.shape, 0.5)! as CoilReliefBorder)
              .relief;
      expect(half.edgeTop.a, closeTo(relief.edgeTop.a / 2, 0.01));
    });
  });

  test('flattenAbove: copyWith, lerp, equality', () {
    final three = CoilPlasticity.subtle.copyWith(flattenAbove: 3);
    expect(three.flattenAbove, 3);
    expect(three.copyWith(amount: 1).flattenAbove, 3);
    expect(three, isNot(CoilPlasticity.subtle));
    expect(three, CoilPlasticity.subtle.copyWith(flattenAbove: 3));
    expect(
      three.hashCode,
      CoilPlasticity.subtle.copyWith(flattenAbove: 3).hashCode,
    );
    expect(
      CoilPlasticity.lerp(CoilPlasticity.subtle, three, 0.4).flattenAbove,
      1,
    );
    expect(
      CoilPlasticity.lerp(CoilPlasticity.subtle, three, 0.6).flattenAbove,
      3,
    );
  });

  group('amount', () {
    test('0 is flat and paints nothing', () {
      expect(CoilPlasticity.flat.amount, 0);
      expect(CoilPlasticity.flat.isFlat, isTrue);
      for (final role in CoilReliefRole.values) {
        for (final b in Brightness.values) {
          expect(CoilPlasticity.flat.resolve(role, b, hover: 1), isNull);
        }
      }
    });

    test('0.5 is subtle, and its wells and fields are unchanged', () {
      expect(CoilPlasticity.subtle.amount, 0.5);
      for (final MapEntry(:key, :value) in _subtleReference.entries) {
        final [role, brightness, hover, press] = key.split(' ');
        final relief = CoilPlasticity.subtle.resolve(
          CoilReliefRole.values.byName(role),
          Brightness.values.byName(brightness),
          hover: double.parse(hover),
          press: double.parse(press),
        );
        expect(_describe(relief), value, reason: key);
      }
    });

    test("0.5's buttons and thumbs are balanced, not retuned", () {
      for (final MapEntry(:key, :value) in _subtleBeforeBalance.entries) {
        final [role, brightness] = key.split(' ');
        final relief = CoilPlasticity.subtle.resolve(
          CoilReliefRole.values.byName(role),
          Brightness.values.byName(brightness),
        )!;
        final now = _alphas(relief);
        for (var i = 0; i < now.length; i++) {
          expect(now[i], closeTo(value[i], 0.08), reason: '$key #$i');
        }
        // The shadows aren't part of the balance.
        expect(relief.shadows, hasLength(2), reason: key);
      }
    });

    test('1 is a little stronger than 0.5, and only in its highlights', () {
      const strong = CoilPlasticity(amount: 1);
      for (final role in [CoilReliefRole.raised, CoilReliefRole.filled]) {
        for (final b in Brightness.values) {
          final half = CoilPlasticity.subtle.resolve(role, b)!;
          final full = strong.resolve(role, b)!;
          final reason = '${role.name} ${b.name}';
          for (final (h, f) in [
            (half.rimTop.a, full.rimTop.a),
            (half.sheenTop.a, full.sheenTop.a),
            (half.edgeTop.a, full.edgeTop.a),
          ]) {
            expect(f, greaterThan(h), reason: reason);
            expect(f, lessThanOrEqualTo(h * 1.4 + 1e-9), reason: reason);
          }
          expect(full.shadows, half.shadows, reason: reason);
          expect(full.rimBottom, half.rimBottom, reason: reason);
        }
      }
      for (final role in [CoilReliefRole.recessed, CoilReliefRole.field]) {
        for (final b in Brightness.values) {
          expect(
            strong.resolve(role, b),
            CoilPlasticity.subtle.resolve(role, b),
          );
        }
      }
    });

    test('in between interpolates', () {
      double rim(double amount) => CoilPlasticity(
        amount: amount,
      ).resolve(.raised, Brightness.light)!.rimTop.a;
      expect(rim(0.25), closeTo(rim(0.5) / 2, 1e-9));
      expect(rim(0.75), greaterThan(rim(0.5)));
      expect(rim(0.75), lessThan(rim(1)));
      expect(
        CoilPlasticity.lerp(CoilPlasticity.flat, CoilPlasticity.subtle, 0.5),
        const CoilPlasticity(amount: 0.25),
      );
      // A spring's overshoot stays in range.
      expect(
        CoilPlasticity.lerp(
          CoilPlasticity.subtle,
          const CoilPlasticity(amount: 1),
          1.2,
        ).amount,
        1,
      );
    });

    test('copyWith and equality', () {
      const p = CoilPlasticity(amount: 0.3, flattenAbove: 3);
      expect(
        p.copyWith(amount: 0.5),
        const CoilPlasticity(amount: 0.5, flattenAbove: 3),
      );
      expect(p.copyWith(), p);
      expect(p, isNot(const CoilPlasticity(amount: 0.3)));
      expect(
        p.hashCode,
        const CoilPlasticity(amount: 0.3, flattenAbove: 3).hashCode,
      );
    });
  });
}

/// [relief] as text, colors to six decimals.
String _describe(CoilRelief? relief) {
  if (relief == null) return 'null';
  String c(Color x) =>
      '${x.a.toStringAsFixed(6)}/${x.r.toStringAsFixed(3)}'
      '${x.g.toStringAsFixed(3)}${x.b.toStringAsFixed(3)}';
  return [
    relief.edgeWidth.toStringAsFixed(4),
    c(relief.edgeTop),
    c(relief.edgeBottom),
    c(relief.rimTop),
    c(relief.rimBottom),
    c(relief.sheenTop),
    c(relief.sheenBottom),
    for (final s in relief.shadows)
      [
        '${c(s.color)}@${s.offset.dy.toStringAsFixed(4)}',
        '~${s.blurRadius.toStringAsFixed(4)}',
        '^${s.spreadRadius.toStringAsFixed(4)}',
      ].join(),
  ].join(' ');
}

/// The alphas of [relief]'s edge, rims and sheen, top then bottom.
List<double> _alphas(CoilRelief relief) => [
  relief.edgeTop.a,
  relief.edgeBottom.a,
  relief.rimTop.a,
  relief.rimBottom.a,
  relief.sheenTop.a,
  relief.sheenBottom.a,
];

/// `CoilPlasticity.subtle` before plasticity became one amount, resolved
/// at rest, hovered and pressed: wells and fields keep it exactly, and
/// quiet buttons and slider tracks stay unlit.
const _subtleReference = {
  'quiet dark 0.0 0.0': 'null',
  'quiet dark 1.0 0.0': 'null',
  'quiet dark 1.0 1.0': 'null',
  'quiet light 0.0 0.0': 'null',
  'quiet light 1.0 0.0': 'null',
  'quiet light 1.0 1.0': 'null',
  'recessed dark 0.0 0.0':
      '0.5000 0.094500/0.0000.0000.000 0.021000/1.0001.0001.000 0.063000/0.0000.0000.000 0.010500/1.0001.0001.000 0.029400/0.0000.0000.000 0.003150/1.0001.0001.000',
  'recessed dark 1.0 0.0':
      '0.5000 0.113400/0.0000.0000.000 0.021000/1.0001.0001.000 0.078750/0.0000.0000.000 0.010500/1.0001.0001.000 0.036750/0.0000.0000.000 0.003150/1.0001.0001.000',
  'recessed dark 1.0 1.0':
      '0.5000 0.090300/0.2500.2500.250 0.044100/0.7500.7500.750 0.059375/0.0000.0000.000 0.005250/1.0001.0001.000 0.019163/0.5000.5000.500 0.010763/0.5000.5000.500',
  'recessed light 0.0 0.0':
      '0.5000 0.027300/0.0000.0000.000 0.006300/0.0000.0000.000 0.012600/0.0000.0000.000 0.105000/1.0001.0001.000 0.007350/0.0000.0000.000 0.042000/1.0001.0001.000',
  'recessed light 1.0 0.0':
      '0.5000 0.032760/0.0000.0000.000 0.006300/0.0000.0000.000 0.015750/0.0000.0000.000 0.105000/1.0001.0001.000 0.009188/0.0000.0000.000 0.042000/1.0001.0001.000',
  'recessed light 1.0 1.0':
      '0.5000 0.026145/0.0000.0000.000 0.012915/0.0000.0000.000 0.060375/0.0000.0000.000 0.052500/1.0001.0001.000 0.015094/0.5000.5000.500 0.023297/0.5000.5000.500',
  'field dark 0.0 0.0':
      '0.5000 0.054000/0.0000.0000.000 0.012000/1.0001.0001.000 0.036000/0.0000.0000.000 0.006000/1.0001.0001.000 0.016800/0.0000.0000.000 0.001800/1.0001.0001.000',
  'field dark 1.0 0.0':
      '0.5000 0.064800/0.0000.0000.000 0.012000/1.0001.0001.000 0.045000/0.0000.0000.000 0.006000/1.0001.0001.000 0.021000/0.0000.0000.000 0.001800/1.0001.0001.000',
  'field dark 1.0 1.0':
      '0.5000 0.051600/0.2500.2500.250 0.025200/0.7500.7500.750 0.042500/0.0000.0000.000 0.003000/1.0001.0001.000 0.010950/0.5000.5000.500 0.006150/0.5000.5000.500',
  'field light 0.0 0.0':
      '0.5000 0.015600/0.0000.0000.000 0.003600/0.0000.0000.000 0.007200/0.0000.0000.000 0.060000/1.0001.0001.000 0.004200/0.0000.0000.000 0.024000/1.0001.0001.000',
  'field light 1.0 0.0':
      '0.5000 0.018720/0.0000.0000.000 0.003600/0.0000.0000.000 0.009000/0.0000.0000.000 0.060000/1.0001.0001.000 0.005250/0.0000.0000.000 0.024000/1.0001.0001.000',
  'field light 1.0 1.0':
      '0.5000 0.014940/0.0000.0000.000 0.007380/0.0000.0000.000 0.034500/0.0000.0000.000 0.030000/1.0001.0001.000 0.008625/0.5000.5000.500 0.013313/0.5000.5000.500',
  'track dark 0.0 0.0': 'null',
  'track dark 1.0 0.0': 'null',
  'track dark 1.0 1.0': 'null',
  'track light 0.0 0.0': 'null',
  'track light 1.0 0.0': 'null',
  'track light 1.0 1.0': 'null',
};

/// The edge, rim and sheen alphas of the raised and filled roles in
/// `CoilPlasticity.subtle` before the balance between primary, secondary
/// and destructive buttons.
const _subtleBeforeBalance = {
  'raised dark': [0.171600, 0.039000, 0.078000, 0.085800, 0.019500, 0.046800],
  'raised light': [0.046800, 0.140400, 0.663000, 0.019500, 0.171600, 0.015600],
  'filled dark': [0.360000, 0.240000, 0.360000, 0.040000, 0.080000, 0.048000],
  'filled light': [0.160000, 0.280000, 0.128000, 0.040000, 0.080000, 0.048000],
};
