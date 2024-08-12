import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('SimpleSpring', () {
    setUp(() {});

    test('is exported by package', () async {
      expect(SimpleSpring, isA<Type>());
    });
  });
}
