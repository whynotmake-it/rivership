import 'package:flutter/services.dart';
import 'package:rivership/rivership.dart';
import 'package:rivership_test/rivership_test.dart';

void main() {
  group('BrightnessTools', () {
    test('inverse should return the opposite brightness', () {
      expect(Brightness.light.inverse, Brightness.dark);
      expect(Brightness.dark.inverse, Brightness.light);
    });

    test('matchingOverlayStyle should return the correct SystemUiOverlayStyle',
        () {
      expect(Brightness.light.matchingOverlayStyle, SystemUiOverlayStyle.light);
      expect(Brightness.dark.matchingOverlayStyle, SystemUiOverlayStyle.dark);
    });

    test('inverseOverlayStyle should return the opposite SystemUiOverlayStyle',
        () {
      expect(Brightness.light.inverseOverlayStyle, SystemUiOverlayStyle.dark);
      expect(Brightness.dark.inverseOverlayStyle, SystemUiOverlayStyle.light);
    });
  });
}
