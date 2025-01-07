import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhero/superhero.dart';

void main() {
  group('SuperheroController', () {
    test('can be instantiated', () {
      expect(SuperheroController(), isA<NavigatorObserver>());
    });
  });
}
