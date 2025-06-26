import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const error = 1e-4;

Matcher equalsSpring(SpringDescription other, {double epsilon = error}) =>
    allOf([
      isA<SpringDescription>(),
      predicate<SpringDescription>(
        (spring) => (spring.mass - other.mass).abs() < epsilon,
        'mass equals ${other.mass}',
      ),
      predicate<SpringDescription>(
        (spring) => (spring.stiffness - other.stiffness).abs() < epsilon,
        'stiffness equals ${other.stiffness}',
      ),
      predicate<SpringDescription>(
        (spring) => (spring.damping - other.damping).abs() < epsilon,
        'damping equals ${other.damping}',
      ),
    ]);
