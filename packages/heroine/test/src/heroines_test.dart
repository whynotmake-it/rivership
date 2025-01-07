import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';

void main() {
  group('HeroineController', () {
    test('can be instantiated', () {
      expect(HeroineController(), isA<NavigatorObserver>());
    });
  });
}
