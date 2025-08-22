import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

// Test data structures
enum TestPhase { small, medium, large }

@immutable
class TestProperties {
  const TestProperties({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is TestProperties &&
      size == other.size &&
      color == other.color &&
      opacity == other.opacity;

  @override
  int get hashCode => Object.hash(size, color, opacity);
}

class TestPropertiesConverter implements MotionConverter<TestProperties> {
  const TestPropertiesConverter();

  @override
  List<double> normalize(TestProperties value) => [
        value.size,
        value.color.red.toDouble(),
        value.color.green.toDouble(),
        value.color.blue.toDouble(),
        value.opacity,
      ];

  @override
  TestProperties denormalize(List<double> values) => TestProperties(
        size: values[0],
        color: Color.fromARGB(
          255,
          values[1].round().clamp(0, 255),
          values[2].round().clamp(0, 255),
          values[3].round().clamp(0, 255),
        ),
        opacity: values[4].clamp(0.0, 1.0),
      );
}

void main() {
  group('PhaseSequence', () {
    test('MapPhaseSequence returns correct values', () {
      const sequence = MapPhaseSequence<double, TestPhase>(
        phaseMap: {
          TestPhase.small: 50.0,
          TestPhase.medium: 100.0,
          TestPhase.large: 150.0,
        },
      );

      expect(sequence.phases,
          [TestPhase.small, TestPhase.medium, TestPhase.large]);
      expect(sequence.valueForPhase(TestPhase.small), 50.0);
      expect(sequence.valueForPhase(TestPhase.medium), 100.0);
      expect(sequence.valueForPhase(TestPhase.large), 150.0);
      expect(sequence.initialPhase, TestPhase.small);
    });

    test('ValuePhaseSequence works with simple values', () {
      const sequence = ValuePhaseSequence<double>(
        values: [0.0, 1.0, 2.0, 3.0],
        autoLoop: true,
      );

      expect(sequence.phases, [0.0, 1.0, 2.0, 3.0]);
      expect(sequence.valueForPhase(1), 1.0);
      expect(sequence.autoLoop, true);
    });

    test('EnumPhaseSequence works with enum values', () {
      final sequence = EnumPhaseSequence<double, TestPhase>(
        enumValues: TestPhase.values,
        valueProvider: (phase) => switch (phase) {
          TestPhase.small => 25.0,
          TestPhase.medium => 50.0,
          TestPhase.large => 100.0,
        },
      );

      expect(sequence.phases, TestPhase.values);
      expect(sequence.valueForPhase(TestPhase.small), 25.0);
      expect(sequence.valueForPhase(TestPhase.medium), 50.0);
      expect(sequence.valueForPhase(TestPhase.large), 100.0);
    });
  });

  group('PhaseController', () {
    testWidgets('controller manages phase transitions', (tester) async {
      const sequence = MapPhaseSequence<TestProperties, TestPhase>(
        phaseMap: {
          TestPhase.small: TestProperties(
            size: 50,
            color: Colors.red,
            opacity: 0.5,
          ),
          TestPhase.medium: TestProperties(
            size: 100,
            color: Colors.green,
            opacity: 0.75,
          ),
          TestPhase.large: TestProperties(
            size: 150,
            color: Colors.blue,
            opacity: 1,
          ),
        },
      );

      final controller = PhaseController<TestProperties, TestPhase>(
        sequence: sequence,
        converter: const TestPropertiesConverter(),
        vsync: tester,
        motion: const LinearMotion(duration: Duration(milliseconds: 100)),
      );

      // Initial phase should be the first one
      expect(controller.currentPhase, TestPhase.small);
      expect(controller.currentPhaseIndex, 0);

      // Move to next phase
      controller.nextPhase();
      expect(controller.currentPhase, TestPhase.medium);
      expect(controller.currentPhaseIndex, 1);

      // Move to specific phase
      controller.goToPhase(TestPhase.large);
      expect(controller.currentPhase, TestPhase.large);
      expect(controller.currentPhaseIndex, 2);

      // Reset to beginning
      controller.reset();
      expect(controller.currentPhase, TestPhase.small);
      expect(controller.currentPhaseIndex, 0);

      controller.dispose();
    });

    testWidgets('controller handles phase change callbacks', (tester) async {
      const sequence = MapPhaseSequence<double, TestPhase>(
        phaseMap: {
          TestPhase.small: 50.0,
          TestPhase.medium: 100.0,
          TestPhase.large: 150.0,
        },
      );

      TestPhase? lastChangedPhase;
      final controller = PhaseController<double, TestPhase>(
        sequence: sequence,
        converter: const SingleMotionConverter(),
        vsync: tester,
        motion: const LinearMotion(duration: Duration(milliseconds: 50)),
        onPhaseChanged: (phase) {
          lastChangedPhase = phase;
        },
      )..nextPhase();
      expect(lastChangedPhase, TestPhase.medium);

      controller.goToPhase(TestPhase.large);
      expect(lastChangedPhase, TestPhase.large);

      controller.dispose();
    });
  });

  group('PhaseMotionBuilder', () {
    testWidgets('builds widget with interpolated values', (tester) async {
      const sequence = MapPhaseSequence<double, TestPhase>(
        phaseMap: {
          TestPhase.small: 50.0,
          TestPhase.medium: 100.0,
          TestPhase.large: 150.0,
        },
      );

      var buildCount = 0;
      double? lastValue;
      TestPhase? lastPhase;

      await tester.pumpWidget(
        MaterialApp(
          home: PhaseMotionBuilder<double, TestPhase>(
            sequence: sequence,
            converter: const SingleMotionConverter(),
            motion: const LinearMotion(duration: Duration(milliseconds: 100)),
            autoStart: false, // Don't auto-start for testing
            builder: (context, value, phase, child) {
              buildCount++;
              lastValue = value;
              lastPhase = phase;
              return SizedBox(
                width: value,
                height: value,
                child: Text('Phase: $phase, Value: $value'),
              );
            },
          ),
        ),
      );

      expect(buildCount, greaterThan(0));
      expect(lastValue, 50.0); // Should start with first phase value
      expect(lastPhase, TestPhase.small);
    });

    testWidgets('responds to trigger changes', (tester) async {
      const sequence = MapPhaseSequence<double, TestPhase>(
        phaseMap: {
          TestPhase.small: 50.0,
          TestPhase.medium: 100.0,
        },
      );

      var trigger = 0;
      TestPhase? lastPhase;

      Widget buildWidget() {
        return MaterialApp(
          home: PhaseMotionBuilder<double, TestPhase>(
            sequence: sequence,
            converter: const SingleMotionConverter(),
            motion: const LinearMotion(duration: Duration(milliseconds: 50)),
            trigger: trigger,
            autoStart: false,
            builder: (context, value, phase, child) {
              lastPhase = phase;
              return SizedBox(
                width: value,
                height: value,
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildWidget());
      expect(lastPhase, TestPhase.small);

      // Change trigger should reset to first phase
      trigger = 1;
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      expect(lastPhase, TestPhase.small);
    });
  });

  group('SinglePhaseMotionBuilder', () {
    testWidgets('works with numeric phases', (tester) async {
      double? lastValue;
      double? lastPhase;

      await tester.pumpWidget(
        MaterialApp(
          home: SinglePhaseMotionBuilder<double>(
            phases: const [0.0, 1.0, 2.0],
            motion: const LinearMotion(duration: Duration(milliseconds: 50)),
            autoStart: false,
            builder: (context, value, phase, child) {
              lastValue = value;
              lastPhase = phase;
              return SizedBox(
                width: value * 100,
                height: value * 100,
              );
            },
          ),
        ),
      );

      expect(lastValue, 0.0);
      expect(lastPhase, 0.0);
    });

    testWidgets('works with enum phases', (tester) async {
      double? lastValue;
      TestPhase? lastPhase;

      await tester.pumpWidget(
        MaterialApp(
          home: SinglePhaseMotionBuilder<TestPhase>(
            phases: TestPhase.values,
            motion: const LinearMotion(duration: Duration(milliseconds: 50)),
            autoStart: false,
            builder: (context, value, phase, child) {
              lastValue = value;
              lastPhase = phase;
              return SizedBox(
                width: (value + 1) * 50,
                height: (value + 1) * 50,
              );
            },
          ),
        ),
      );

      expect(lastValue, 0.0); // Index of first enum value
      expect(lastPhase, TestPhase.small);
    });
  });

  group('Integration', () {
    testWidgets('phase animations work with physics motions', (tester) async {
      const sequence = MapPhaseSequence<double, TestPhase>(
        phaseMap: {
          TestPhase.small: 0.0,
          TestPhase.medium: 1.0,
          TestPhase.large: 2.0,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PhaseMotionBuilder<double, TestPhase>(
            sequence: sequence,
            converter: const SingleMotionConverter(),
            motion: const CupertinoMotion.bouncy(), // Physics-based motion
            autoStart: false,
            builder: (context, value, phase, child) {
              return SizedBox(
                width: (value + 1) * 100,
                height: (value + 1) * 100,
                child: Text('$value'),
              );
            },
          ),
        ),
      );

      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('phase animations work with complex properties',
        (tester) async {
      const sequence = MapPhaseSequence<TestProperties, TestPhase>(
        phaseMap: {
          TestPhase.small: TestProperties(
            size: 50,
            color: Colors.red,
            opacity: 0.5,
          ),
          TestPhase.large: TestProperties(
            size: 150,
            color: Colors.blue,
            opacity: 1,
          ),
        },
      );

      TestProperties? lastProperties;

      await tester.pumpWidget(
        MaterialApp(
          home: PhaseMotionBuilder<TestProperties, TestPhase>(
            sequence: sequence,
            converter: const TestPropertiesConverter(),
            motion: const LinearMotion(duration: Duration(milliseconds: 100)),
            autoStart: false,
            builder: (context, properties, phase, child) {
              lastProperties = properties;
              return Container(
                width: properties.size,
                height: properties.size,
                color: properties.color.withValues(alpha: properties.opacity),
              );
            },
          ),
        ),
      );

      expect(lastProperties?.size, 50.0);
      expect(lastProperties?.color.toARGB32(), Colors.red.toARGB32());
      expect(lastProperties?.opacity, 0.5);
    });
  });
}
