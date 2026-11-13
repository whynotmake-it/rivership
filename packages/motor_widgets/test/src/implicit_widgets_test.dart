import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

import '../util.dart';

/// One implicitly animated widget, driven by a number `t` that it maps to
/// its property, and read back as that number.
class _Case {
  const _Case(this.name, this.build, this.read);

  final String name;

  /// Builds the widget with its property at `t` (0 to 1).
  final Widget Function(double t, Motion motion) build;

  /// Reads the property back as `t`.
  final double Function(WidgetTester tester) read;
}

const _box = SizedBox(width: 20, height: 20);

T _below<T extends Widget>(WidgetTester tester, Type of) => tester.widget<T>(
  find.descendant(of: find.byType(of), matching: find.byType(T)).first,
);

final _cases = [
  _Case(
    'MotionOpacity',
    (t, motion) => MotionOpacity(opacity: t, motion: motion, child: _box),
    (tester) => _below<Opacity>(tester, MotionOpacity).opacity,
  ),
  _Case(
    'MotionScale',
    (t, motion) => MotionScale(scale: 1 + t, motion: motion, child: _box),
    (tester) => _below<Transform>(tester, MotionScale).transform.storage[0] - 1,
  ),
  _Case(
    'MotionRotation',
    (t, motion) => MotionRotation(turns: t / 4, motion: motion, child: _box),
    (tester) {
      final storage = _below<Transform>(
        tester,
        MotionRotation,
      ).transform.storage;
      return math.atan2(storage[1], storage[0]) / (math.pi / 2);
    },
  ),
  _Case(
    'MotionSlide',
    (t, motion) =>
        MotionSlide(offset: Offset(t, 0), motion: motion, child: _box),
    (tester) =>
        _below<FractionalTranslation>(tester, MotionSlide).translation.dx,
  ),
  _Case(
    'MotionAlign',
    (t, motion) => MotionAlign(
      alignment: Alignment(t, 0),
      motion: motion,
      child: _box,
    ),
    (tester) => (_below<Align>(tester, MotionAlign).alignment as Alignment).x,
  ),
  _Case(
    'MotionPositioned',
    (t, motion) => Stack(
      children: [
        MotionPositioned(left: 100 * t, top: 0, motion: motion, child: _box),
      ],
    ),
    (tester) => _below<Positioned>(tester, MotionPositioned).left! / 100,
  ),
  _Case(
    'MotionPadding',
    (t, motion) => MotionPadding(
      padding: EdgeInsets.only(left: 100 * t),
      motion: motion,
      child: _box,
    ),
    (tester) =>
        (_below<PaddingExtended>(tester, MotionPadding).padding as EdgeInsets)
            .left /
        100,
  ),
  _Case(
    'MotionContainer',
    (t, motion) => MotionContainer(
      width: 100 + 100 * t,
      height: 20,
      motion: motion,
    ),
    (tester) => tester.getSize(find.byType(MotionContainer)).width / 100 - 1,
  ),
  _Case(
    'MotionSize',
    (t, motion) => MotionSize(
      motion: motion,
      child: SizedBox(width: 100 + 100 * t, height: 20),
    ),
    (tester) => tester.getSize(find.byType(MotionSize)).width / 100 - 1,
  ),
];

Widget _wrap(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  const spring = CupertinoMotion.smooth();

  for (final c in _cases) {
    group(c.name, () {
      Future<void> pumpAt(WidgetTester tester, double t, [Motion? motion]) =>
          tester.pumpWidget(_wrap(c.build(t, motion ?? spring)));

      testWidgets('starts at its value without animating', (tester) async {
        await pumpAt(tester, 0.5);
        expect(c.read(tester), closeTo(0.5, 1e-12));
        await tester.pump(frame);
        expect(c.read(tester), closeTo(0.5, 1e-12));
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('springs to a new value and settles exactly on it', (
        tester,
      ) async {
        await pumpAt(tester, 0);
        await pumpAt(tester, 1);
        await tester.pump(frame);
        await tester.pump(frame * 4);
        final midway = c.read(tester);
        expect(midway, greaterThan(0));
        expect(midway, lessThan(1));

        await tester.pumpAndSettle(frame);
        expect(c.read(tester), closeTo(1, 1e-12));
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('keeps its velocity when retargeted mid-flight', (
        tester,
      ) async {
        await pumpAt(tester, 0);
        await pumpAt(tester, 0.5);
        final samples = <double>[c.read(tester)];
        for (var i = 0; i < 6; i++) {
          await tester.pump(fineFrame);
          samples.add(c.read(tester));
        }
        // Retarget in this frame: the old spring advances, then the widget
        // rebuilds with the new target.
        await pumpAt(tester, 1);
        await tester.pump(fineFrame);
        samples.add(c.read(tester));
        for (var i = 0; i < 6; i++) {
          await tester.pump(fineFrame);
          samples.add(c.read(tester));
        }
        expectContinuousVelocity(samples, retargetAt: 7);

        await tester.pumpAndSettle(frame);
        expect(c.read(tester), closeTo(1, 1e-12));
      });

      testWidgets('jumps with Motion.instant()', (tester) async {
        await pumpAt(tester, 0, const Motion.instant());
        await pumpAt(tester, 1, const Motion.instant());
        await tester.pump();
        expect(c.read(tester), closeTo(1, 1e-12));
        await tester.pump(frame);
        expect(c.read(tester), closeTo(1, 1e-12));
        expect(tester.hasRunningAnimations, isFalse);
      });
    });
  }

  group('MotionContainer', () {
    Widget container({required double width, required Color color}) => _wrap(
      MotionContainer(
        width: width,
        height: 20,
        color: color,
        motion: spring,
      ),
    );

    Color colorOf(WidgetTester tester) => _below<ColoredBox>(
      tester,
      MotionContainer,
    ).color;

    testWidgets('changing one property does not disturb another in flight', (
      tester,
    ) async {
      Future<List<double>> widths({required bool changeColor}) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          container(width: 100, color: const Color(0xFF000000)),
        );
        await tester.pumpWidget(
          container(width: 200, color: const Color(0xFF000000)),
        );
        final widths = <double>[];
        for (var i = 0; i < 20; i++) {
          if (i == 5 && changeColor) {
            await tester.pumpWidget(
              container(width: 200, color: const Color(0xFFFFFFFF)),
            );
          }
          await tester.pump(frame);
          widths.add(tester.getSize(find.byType(MotionContainer)).width);
        }
        return widths;
      }

      final reference = await widths(changeColor: false);
      final withColorChange = await widths(changeColor: true);
      expect(withColorChange, reference);
      expect(colorOf(tester), isNot(const Color(0xFFFFFFFF)));

      await tester.pumpAndSettle();
      expect(colorOf(tester), const Color(0xFFFFFFFF));
    });

    testWidgets('motions gives one track its own motion', (tester) async {
      Widget build(double width, Color color) => _wrap(
        MotionContainer(
          width: width,
          height: 20,
          color: color,
          motion: spring,
          // Dot shorthand resolves on MotionContainerTrack.
          motions: {.color: const Motion.instant()},
        ),
      );
      await tester.pumpWidget(build(100, const Color(0xFF000000)));
      await tester.pumpWidget(build(200, const Color(0xFFFFFFFF)));
      await tester.pump(frame);
      await tester.pump(frame);
      expect(colorOf(tester), const Color(0xFFFFFFFF));
      expect(
        tester.getSize(find.byType(MotionContainer)).width,
        inExclusiveRange(100, 200),
      );
    });

    testWidgets('a rebuilt motions map with equal motions redirects nothing', (
      tester,
    ) async {
      Future<List<double>> widths({required bool rebuild}) async {
        Widget build(double width) => _wrap(
          MotionContainer(
            width: width,
            height: 20,
            motion: spring,
            motions: {
              MotionContainerTrack.minWidth: const CupertinoMotion.smooth(),
              MotionContainerTrack.maxWidth: const CupertinoMotion.smooth(),
            },
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(build(100));
        await tester.pumpWidget(build(200));
        final widths = <double>[];
        for (var i = 0; i < 20; i++) {
          if (rebuild && i == 5) await tester.pumpWidget(build(200));
          await tester.pump(frame);
          widths.add(tester.getSize(find.byType(MotionContainer)).width);
        }
        return widths;
      }

      expect(await widths(rebuild: true), await widths(rebuild: false));
    });

    testWidgets('animates decoration color and border radius', (tester) async {
      Widget build(double radius, Color color) => _wrap(
        MotionContainer(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
          motion: spring,
        ),
      );
      BoxDecoration decoration() =>
          _below<DecoratedBox>(tester, MotionContainer).decoration
              as BoxDecoration;

      await tester.pumpWidget(build(0, const Color(0xFF000000)));
      await tester.pumpWidget(build(20, const Color(0xFFFFFFFF)));
      await tester.pump(frame * 6);
      final radius = decoration().borderRadius! as BorderRadius;
      expect(radius.topLeft.x, inExclusiveRange(0, 20));
      expect(decoration().color!.r, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(decoration().borderRadius, BorderRadius.circular(20));
      expect(decoration().color, const Color(0xFFFFFFFF));
    });

    testWidgets('animates padding, margin, alignment and transform', (
      tester,
    ) async {
      Widget build(double t) => _wrap(
        MotionContainer(
          width: 100,
          height: 100,
          padding: EdgeInsets.all(10 * t),
          margin: EdgeInsets.all(10 * t),
          alignment: Alignment(t, t),
          transform: Matrix4.translationValues(10 * t, 0, 0),
          motion: spring,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump(frame * 6);
      final offset = tester.getTopLeft(find.byWidget(_box));
      expect(offset.dx, inExclusiveRange(0, 10 + 10 + 10 + 60));

      await tester.pumpAndSettle();
      // Translation 10, margin 10, padding 10, aligned to the bottom right
      // of the 80 px content box.
      expect(tester.getTopLeft(find.byWidget(_box)), const Offset(90, 80));
    });

    testWidgets('a property that appears starts at its value', (tester) async {
      await tester.pumpWidget(_wrap(MotionContainer(motion: spring)));
      await tester.pumpWidget(
        _wrap(MotionContainer(width: 80, height: 10, motion: spring)),
      );
      expect(tester.getSize(find.byType(MotionContainer)), const Size(80, 10));
      await tester.pump(frame);
      expect(tester.getSize(find.byType(MotionContainer)), const Size(80, 10));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('allows constraints with an infinite bound', (tester) async {
      Widget build(double minHeight) => _wrap(
        MotionContainer(
          constraints: BoxConstraints(minHeight: minHeight),
          motion: spring,
          child: _box,
        ),
      );
      await tester.pumpWidget(build(20));
      await tester.pumpWidget(build(60));
      await tester.pump(frame * 4);
      expect(
        tester.getSize(find.byType(MotionContainer)).height,
        inExclusiveRange(20, 60),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MotionContainer)).height, 60);
    });
  });

  testWidgets('MotionAlign and MotionPositioned take per-track motions', (
    tester,
  ) async {
    Widget build(double t) => _wrap(
      SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          children: [
            MotionPositioned(
              left: 100 * t,
              top: 100 * t,
              motion: spring,
              motions: {.top: const Motion.instant()},
              child: MotionAlign(
                alignment: Alignment(t, t),
                widthFactor: 1 + t,
                motion: spring,
                motions: {.widthFactor: const Motion.instant()},
                child: _box,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(0));
    await tester.pumpWidget(build(1));
    await tester.pump(frame);
    await tester.pump(frame);
    final positioned = _below<Positioned>(tester, MotionPositioned);
    expect(positioned.top, 100);
    expect(positioned.left, inExclusiveRange(0, 100));
    final align = _below<Align>(tester, MotionAlign);
    expect(align.widthFactor, 2);
    expect((align.alignment as Alignment).x, inExclusiveRange(0, 1));
  });

  testWidgets('onEnd is called when the motion settles', (tester) async {
    var ends = 0;
    Widget build(double opacity) => _wrap(
      MotionOpacity(
        opacity: opacity,
        motion: spring,
        onEnd: () => ends++,
        child: _box,
      ),
    );
    await tester.pumpWidget(build(0));
    await tester.pumpWidget(build(1));
    await tester.pump(frame);
    expect(ends, 0);
    await tester.pumpAndSettle();
    expect(ends, 1);
  });

  group('MotionSize', () {
    testWidgets('clips and aligns the child while smaller than it', (
      tester,
    ) async {
      Widget build(double width) => _wrap(
        MotionSize(
          motion: spring,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: width, height: 20),
        ),
      );
      await tester.pumpWidget(build(100));
      await tester.pumpWidget(build(200));
      await tester.pump(frame * 4);
      final size = tester.getSize(find.byType(MotionSize));
      expect(size.width, inExclusiveRange(100, 200));
      expect(
        tester.getTopLeft(find.byType(SizedBox).last),
        tester.getTopLeft(find.byType(MotionSize)),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MotionSize)), const Size(200, 20));
    });

    testWidgets('stops when the child goes away mid-flight', (tester) async {
      Widget build({required bool child}) => _wrap(
        MotionSize(
          motion: spring,
          child: child ? const SizedBox(width: 200, height: 20) : null,
        ),
      );
      await tester.pumpWidget(_wrap(const MotionSize(motion: spring)));
      await tester.pumpWidget(build(child: true));
      await tester.pumpWidget(
        _wrap(
          const MotionSize(
            motion: spring,
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );
      await tester.pump(frame * 3);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(build(child: false));
      expect(tester.getSize(find.byType(MotionSize)), Size.zero);
      await tester.pump(frame);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('takes the smallest size without a child', (tester) async {
      await tester.pumpWidget(_wrap(const MotionSize(motion: spring)));
      expect(tester.getSize(find.byType(MotionSize)), Size.zero);
    });
  });
}
