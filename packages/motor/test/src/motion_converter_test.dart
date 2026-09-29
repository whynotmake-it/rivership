import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('ColorRgbMotionConverter', () {
    const converter = ColorRgbMotionConverter();

    test('normalizes a color to its RGBA components', () {
      for (final (color, expected) in [
        (
          const Color(0xFF123456),
          [
            closeTo(0.0706, error),
            closeTo(0.2039, error),
            closeTo(0.3373, error),
            1.0,
          ],
        ),
        (const Color(0x00000000), [0.0, 0.0, 0.0, 0.0]),
        (const Color(0xFFFFFFFF), [1.0, 1.0, 1.0, 1.0]),
        (const Color(0x80FF0000), [1.0, 0.0, 0.0, closeTo(0.502, error)]),
      ]) {
        expect(converter.normalize(color), expected, reason: '$color');
      }
    });

    test('denormalizes RGBA components, clamping each to 0..1', () {
      for (final (values, expected) in const [
        ([0.5, 0.25, 0.75, 0.8], [0.5, 0.25, 0.75, 0.8]),
        ([0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]),
        ([1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]),
        ([1.5, 2.0, 3.0, 1.2], [1.0, 1.0, 1.0, 1.0]),
        ([-0.5, -1.0, -2.0, -0.1], [0.0, 0.0, 0.0, 0.0]),
        ([-0.5, 0.5, 1.5, 0.3], [0.0, 0.5, 1.0, 0.3]),
        ([100.0, -50.0, 999.9, 0.0], [1.0, 0.0, 1.0, 0.0]),
        (
          [double.infinity, double.negativeInfinity, 0.5, 0.5],
          [1.0, 0.0, 0.5, 0.5],
        ),
      ]) {
        final result = converter.denormalize(values);
        expect(
          [result.r, result.g, result.b, result.a],
          equals(expected),
          reason: '$values',
        );
      }
      expect(
        () => converter.denormalize([double.nan, 0.5, 0.5, 1.0]),
        returnsNormally,
      );
    });

    test('round-trips colors', () {
      for (final color in const [
        Color(0xFF4A90E2),
        Color(0x40808080),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFFFF0000),
        Color(0xFF00FF00),
        Color(0xFF0000FF),
        Color(0x80FF8000),
        Color(0x20C0C0C0),
      ]) {
        final roundTripped = converter.denormalize(converter.normalize(color));
        expect(roundTripped.r, closeTo(color.r, error), reason: '$color');
        expect(roundTripped.g, closeTo(color.g, error), reason: '$color');
        expect(roundTripped.b, closeTo(color.b, error), reason: '$color');
        expect(roundTripped.a, closeTo(color.a, error), reason: '$color');
      }
    });
  });
}
