import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('ColorRgbMotionConverter', () {
    const converter = ColorRgbMotionConverter();

    group('normalize', () {
      test('converts basic color to RGBA values', () {
        const color = Color(0xFF123456);
        final result = converter.normalize(color);

        expect(result, hasLength(4));
        expect(result[0], closeTo(0.0706, 0.001)); // Red: 0x12 / 255 ≈ 0.0706
        expect(result[1], closeTo(0.2039, 0.001)); // Green: 0x34 / 255 ≈ 0.2039
        expect(result[2], closeTo(0.3373, 0.001)); // Blue: 0x56 / 255 ≈ 0.3373
        expect(result[3], equals(1.0)); // Alpha: 0xFF / 255 = 1.0
      });

      test('converts transparent color', () {
        const color = Color(0x00000000);
        final result = converter.normalize(color);

        expect(result, equals([0.0, 0.0, 0.0, 0.0]));
      });

      test('converts white color', () {
        const color = Color(0xFFFFFFFF);
        final result = converter.normalize(color);

        expect(result, equals([1.0, 1.0, 1.0, 1.0]));
      });

      test('converts semi-transparent color', () {
        const color = Color(0x80FF0000); // 50% transparent red
        final result = converter.normalize(color);

        expect(result[0], equals(1.0)); // Red
        expect(result[1], equals(0.0)); // Green
        expect(result[2], equals(0.0)); // Blue
        expect(result[3], closeTo(0.502, 0.001)); // Alpha: 0x80 / 255 ≈ 0.502
      });
    });

    group('denormalize', () {
      test('converts RGBA values back to color', () {
        final values = [0.5, 0.25, 0.75, 0.8];
        final result = converter.denormalize(values);

        expect(result.r, equals(0.5));
        expect(result.g, equals(0.25));
        expect(result.b, equals(0.75));
        expect(result.a, equals(0.8));
      });

      test('converts zero values to transparent black', () {
        final values = [0.0, 0.0, 0.0, 0.0];
        final result = converter.denormalize(values);

        expect(result.r, equals(0.0));
        expect(result.g, equals(0.0));
        expect(result.b, equals(0.0));
        expect(result.a, equals(0.0));
      });

      test('converts max values to white', () {
        final values = [1.0, 1.0, 1.0, 1.0];
        final result = converter.denormalize(values);

        expect(result.r, equals(1.0));
        expect(result.g, equals(1.0));
        expect(result.b, equals(1.0));
        expect(result.a, equals(1.0));
      });

      test('clamps overshooting values above 1.0', () {
        final values = [1.5, 2.0, 3.0, 1.2];
        final result = converter.denormalize(values);

        // All values should be clamped to 1.0
        expect(result.r, equals(1.0));
        expect(result.g, equals(1.0));
        expect(result.b, equals(1.0));
        expect(result.a, equals(1.0));
      });

      test('clamps undershooting values below 0.0', () {
        final values = [-0.5, -1.0, -2.0, -0.1];
        final result = converter.denormalize(values);

        // All values should be clamped to 0.0
        expect(result.r, equals(0.0));
        expect(result.g, equals(0.0));
        expect(result.b, equals(0.0));
        expect(result.a, equals(0.0));
      });

      test('handles mixed over/undershooting values', () {
        final values = [-0.5, 0.5, 1.5, 0.3];
        final result = converter.denormalize(values);

        expect(result.r, equals(0.0)); // Clamped from -0.5
        expect(result.g, equals(0.5)); // Normal value
        expect(result.b, equals(1.0)); // Clamped from 1.5
        expect(result.a, equals(0.3)); // Normal value
      });

      test('handles extreme overshooting values', () {
        final values = [100.0, -50.0, 999.9, 0.0];
        final result = converter.denormalize(values);

        expect(result.r, equals(1.0)); // Clamped from 100.0
        expect(result.g, equals(0.0)); // Clamped from -50.0
        expect(result.b, equals(1.0)); // Clamped from 999.9
        expect(result.a, equals(0.0)); // Normal value
      });
    });

    group('roundtrip conversion', () {
      test('normalize then denormalize preserves original color', () {
        const originalColor = Color(0xFF4A90E2);

        final normalized = converter.normalize(originalColor);
        final denormalized = converter.denormalize(normalized);

        // Due to floating point precision, we use closeTo for comparison
        expect(denormalized.r, closeTo(originalColor.r, 0.001));
        expect(denormalized.g, closeTo(originalColor.g, 0.001));
        expect(denormalized.b, closeTo(originalColor.b, 0.001));
        expect(denormalized.a, closeTo(originalColor.a, 0.001));
      });

      test('roundtrip with transparent color', () {
        const originalColor = Color(0x40808080);

        final normalized = converter.normalize(originalColor);
        final denormalized = converter.denormalize(normalized);

        expect(denormalized.r, closeTo(originalColor.r, 0.001));
        expect(denormalized.g, closeTo(originalColor.g, 0.001));
        expect(denormalized.b, closeTo(originalColor.b, 0.001));
        expect(denormalized.a, closeTo(originalColor.a, 0.001));
      });

      test('multiple colors roundtrip correctly', () {
        final testColors = [
          const Color(0xFF000000), // Black
          const Color(0xFFFFFFFF), // White
          const Color(0xFFFF0000), // Red
          const Color(0xFF00FF00), // Green
          const Color(0xFF0000FF), // Blue
          const Color(0x80FF8000), // Semi-transparent orange
          const Color(0x20C0C0C0), // Very transparent light gray
        ];

        for (final color in testColors) {
          final normalized = converter.normalize(color);
          final denormalized = converter.denormalize(normalized);

          expect(
            denormalized.r,
            closeTo(color.r, 0.001),
            reason: 'Red component failed for $color',
          );
          expect(
            denormalized.g,
            closeTo(color.g, 0.001),
            reason: 'Green component failed for $color',
          );
          expect(
            denormalized.b,
            closeTo(color.b, 0.001),
            reason: 'Blue component failed for $color',
          );
          expect(
            denormalized.a,
            closeTo(color.a, 0.001),
            reason: 'Alpha component failed for $color',
          );
        }
      });
    });

    group('edge cases', () {
      test('handles NaN values gracefully', () {
        final values = [double.nan, 0.5, 0.5, 1.0];

        // The Color.from constructor should handle NaN values
        // by either clamping or throwing - we test that it doesn't crash
        expect(() => converter.denormalize(values), returnsNormally);
      });

      test('handles infinity values', () {
        final values = [double.infinity, double.negativeInfinity, 0.5, 0.5];

        final result = converter.denormalize(values);

        // Infinity should be clamped to 1.0, negative infinity to 0.0
        expect(result.r, equals(1.0));
        expect(result.g, equals(0.0));
        expect(result.b, equals(0.5));
        expect(result.a, equals(0.5));
      });
    });
  });
}
