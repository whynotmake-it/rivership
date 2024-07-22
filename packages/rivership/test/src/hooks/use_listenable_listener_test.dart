import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('useListenableListener', () {
    setUp(() {});

    test('is exported by package', () async {
      expect(useListenableListener, isA<Function>());
    });
  });
}
