import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('MotionBuilder Golden Tests', () {
    const frameSize = Size(200, 2);
    const rectSize = 2.0;

    late AnimationSheetBuilder animationSheet;

    setUp(() {
      animationSheet = AnimationSheetBuilder(frameSize: frameSize);
    });

    Widget buildTestApp({
      required double value,
      double? from,
      bool active = true,
    }) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox(
            width: frameSize.width,
            height: frameSize.height,
            child: SingleMotionBuilder(
              value: value,
              from: from,
              active: active,
              motion: const CupertinoMotion.bouncy(),
              builder: (context, offset, child) {
                return Stack(
                  children: [
                    Positioned(
                      left: offset,
                      child: Container(
                        width: rectSize,
                        height: rectSize,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('1D horizontal animation from start to end', (tester) async {
      final widget = animationSheet.record(
        buildTestApp(
          value: 170,
          from: 10,
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpFrames(widget, const Duration(milliseconds: 2000));

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/motion_builder_1d_animation.png'),
      );
    });

    testWidgets('value change triggers animation correctly', (tester) async {
      var currentValue = 20.0;
      void Function(void Function())? setStateFn;

      final widget = animationSheet.record(
        StatefulBuilder(
          builder: (context, setState) {
            setStateFn = setState;
            return buildTestApp(value: currentValue);
          },
        ),
      );

      await tester.pumpWidget(widget);

      setStateFn!(() {
        currentValue = 90.0;
      });

      await tester.pumpFrames(widget, const Duration(milliseconds: 200));

      setStateFn!(() {
        currentValue = 160.0;
      });

      await tester.pumpFrames(widget, const Duration(milliseconds: 500));

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/motion_builder_manual_changes.png'),
      );
    });

    testWidgets('2D animation with MotionBuilder', (tester) async {
      Widget build2DTestApp({
        required (double, double) value,
        (double, double)? from,
      }) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox(
              width: frameSize.width,
              height: frameSize.height,
              child: MotionBuilder(
                value: value,
                from: from,
                motion: const CupertinoMotion.bouncy(),
                converter: MotionConverter<(double, double)>(
                  normalize: (value) => [value.$1, value.$2],
                  denormalize: (values) => (values[0], values[1]),
                ),
                builder: (context, position, child) {
                  return Stack(
                    children: [
                      Positioned(
                        left: position.$1,
                        top: position.$2,
                        child: Container(
                          width: rectSize,
                          height: rectSize,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      }

      final widget = animationSheet.record(
        build2DTestApp(
          value: (170.0, 0.0),
          from: (10.0, 0.0),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpFrames(widget, const Duration(milliseconds: 2000));

      await expectLater(
        animationSheet.collate(1),
        matchesGoldenFile('golden/motion_builder_2d_animation.png'),
      );
    });
  });
}
