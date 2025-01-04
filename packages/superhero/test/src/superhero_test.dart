// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:superhero/superhero.dart';

void main() {
  group('Superhero', () {
    test('can be instantiated', () {
      expect(Superhero(), isNotNull);
    });
  });
}
