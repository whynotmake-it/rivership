import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('StringIfNotEmpty', () {
    test('returns null for empty string', () async {
      expect(''.ifNotEmpty(), null);
    });

    test('returns the String for other chars', () async {
      for (final char in ['a', ' ', '1', '!', '🎉']) {
        expect(char.ifNotEmpty(), char);
      }
    });
  });
}
