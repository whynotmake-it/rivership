import 'package:rivership/rivership.dart';
import 'package:rivership_test/rivership_test.dart';

void main() {
  group('ObjectTryAs', () {
    test('tryAs returns correct value when cast is successful', () {
      const obj = 'Hello';
      final result = obj.tryAs<String>();
      expect(result, 'Hello');
    });

    test('tryAs returns null when cast fails', () {
      const obj = 'Hello';
      final result = obj.tryAs<int>();
      expect(result, null);
    });

    test('tryAs does nice type inference', () {
      const obj = 'Hello';
      // ignore: omit_local_variable_types
      final int? result = obj.tryAs();
      expect(result, null);
    });
  });
}
