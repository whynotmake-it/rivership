import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:rivership/rivership.dart';
import 'package:rivership_test/rivership_test.dart';

const _duration = Duration(seconds: 1);

final _state = StateProvider.autoDispose((ref) => 0);

final _cached = Provider.autoDispose((ref) {
  final state = ref.watch(_state);
  ref.cacheFor(_duration);
  return state;
});

void main() {
  group('AutoDisposeRefCache', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer.test();
    });

    group('cacheFor', () {
      test('disposes after duration', () async {
        fakeAsync((async) {
          expect(container.read(_cached), 0);
          container.read(_state.notifier).state++;
          expect(container.read(_cached), 1);
          async.elapse(_duration);
          expect(container.read(_cached), 0);
        });
      });

      test('holds the cached value in between', () async {
        fakeAsync((async) {
          expect(container.read(_cached), 0);
          container.read(_state.notifier).state++;
          // Test 10 intervals in between
          for (var i = 0; i < 10; i++) {
            expect(container.read(_cached), 1);
            async.elapse(_duration ~/ 10);
          }
          // After advancing 1/10th of the duration 10 times, the value should be gone
          expect(container.read(_cached), 0);
        });
      });
    });
  });
}
