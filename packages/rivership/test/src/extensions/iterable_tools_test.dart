import 'package:rivership/src/extensions/iterable_tools.dart';
import 'package:rivership_test/rivership_test.dart';

void main() {
  group('IterableTools', () {
    test('tryElementAt returns correct element or null', () {
      final list = [1, 2, 3];
      expect(list.tryElementAt(0), 1);
      expect(list.tryElementAt(2), 3);
      expect(list.tryElementAt(3), null);
    });

    test('uniqueBy returns unique elements by key', () {
      final list = ['apple', 'banana', 'apricot'];
      final result = list.uniqueBy((e) => e[0]).toList();
      expect(result, ['apple', 'banana']);
    });

    test('intersperse inserts element between elements', () {
      final list = [1, 2, 3];
      final result = list.intersperse(0).toList();
      expect(result, [1, 0, 2, 0, 3]);
    });

    test('intersperseOuter inserts element between and around elements', () {
      final list = [1, 2, 3];
      final result = list.intersperseOuter(0).toList();
      expect(result, [0, 1, 0, 2, 0, 3, 0]);
    });

    test('chunked splits list into chunks of given size', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2).toList();
      expect(result, [
        [1, 2],
        [3, 4],
        [5]
      ]);
    });

    test('chunked throws error for non-positive size', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(0).toList(), throwsArgumentError);
    });
  });
}
