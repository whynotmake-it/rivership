import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('AsyncValueTools', () {
    const loading = AsyncLoading<int>();
    const data = AsyncData(42);
    final error = AsyncError<int>(Exception(), StackTrace.empty);

    group('isLoadingInitial', () {
      test('is true for empty AsyncLoading', () async {
        expect(loading.isLoadingInitial, isTrue);
      });

      test('is true if previous is loading', () async {
        expect(loading.copyWithPrevious(loading).isLoadingInitial, isTrue);
      });

      test('is false for AsyncLoading with previous', () async {
        expect(loading.copyWithPrevious(data).isLoadingInitial, isFalse);
        expect(loading.copyWithPrevious(error).isLoadingInitial, isFalse);
      });

      test('is false for any data', () async {
        expect(data.isLoadingInitial, isFalse);
        expect(data.copyWithPrevious(data).isLoadingInitial, isFalse);
        expect(data.copyWithPrevious(loading).isLoadingInitial, isFalse);
        expect(data.copyWithPrevious(error).isLoadingInitial, isFalse);
      });

      test('is false for any error', () async {
        expect(error.isLoadingInitial, isFalse);
        expect(error.copyWithPrevious(data).isLoadingInitial, isFalse);
        expect(error.copyWithPrevious(loading).isLoadingInitial, isFalse);
        expect(error.copyWithPrevious(error).isLoadingInitial, isFalse);
      });
    });
  });
}
