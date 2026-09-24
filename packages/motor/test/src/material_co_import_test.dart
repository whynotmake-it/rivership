import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// Regression test for the `Step` ↔ Material `Step` name collision.
///
/// Importing both `package:flutter/material.dart` (which exports the
/// `Stepper` row widget `Step`) and `package:motor/motor.dart` must not
/// produce ambiguous names: motor's step type is `TrackStep`. This file
/// compiling and analyzing cleanly is the primary assertion.
void main() {
  test('material and motor co-import without name collisions', () {
    const steps = <TrackStep<double>>[
      TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 100))),
      TrackStep.hold(Duration(milliseconds: 50)),
      StepSync(token: #barrier),
    ];
    expect(steps, hasLength(3));

    // Material's Step remains directly usable alongside motor.
    const materialStep = Step(title: Text('title'), content: Text('content'));
    expect(materialStep.title, isA<Text>());
  });
}
