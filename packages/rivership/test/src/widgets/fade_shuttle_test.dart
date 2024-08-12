import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('AnimatedSizeSwitcher', () {
    setUp(() {});

    test('is exported by package and a valid FlightShuttleBuilder', () async {
      expect(fadeShuttle, isA<HeroFlightShuttleBuilder>());
    });
  });
}
