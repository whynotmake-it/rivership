/// Extension methods for the `Iterable` class.
extension IterableTools<T> on Iterable<T> {
  /// Attempts to get the element at [index].
  ///
  /// If [index] is out of range, returns null.
  T? tryElementAt(int index) {
    try {
      return elementAt(index);
    } catch (_) {
      return null;
    }
  }

  /// Returns an [Iterable] containing elements that are unique by a key, which
  /// is extracted from each element by [keyOf].
  Iterable<T> uniqueBy<K>(K Function(T element) keyOf) {
    final seen = <K>{};
    return where((element) => seen.add(keyOf(element)));
  }

  /// Puts [element] between every element in this Iterable.
  ///
  /// Example:
  ///
  ///     final list1 = intersperse(2, <int>[]); // [];
  ///     final list2 = intersperse(2, [0]); // [0];
  ///     final list3 = intersperse(2, [0, 0]); // [0, 2, 0];
  ///
  Iterable<T> intersperse(T element) sync* {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      yield iterator.current;
      while (iterator.moveNext()) {
        yield element;
        yield iterator.current;
      }
    }
  }

  /// Puts [element] between every element in [list] and at the bounds of [list].
  ///
  /// Example:
  ///
  ///     final list1 = intersperseOuter(2, <int>[]); // [];
  ///     final list2 = intersperseOuter(2, [0]); // [2, 0, 2];
  ///     final list3 = intersperseOuter(2, [0, 0]); // [2, 0, 2, 0, 2];
  ///
  Iterable<T> intersperseOuter(T element) sync* {
    final iterator = this.iterator;
    if (isNotEmpty) {
      yield element;
    }
    while (iterator.moveNext()) {
      yield iterator.current;
      yield element;
    }
  }

  /// Splits this collection into a new lazy [Iterable] of lists each not
  /// exceeding the given [size].
  ///
  /// The last list in the resulting list may have less elements than the given
  /// [size].
  ///
  /// [size] must be positive and can be greater than the number of elements in
  /// this collection.
  Iterable<List<T>> chunked(int size) sync* {
    if (size < 1) {
      throw ArgumentError('Requested chunk size $size is less than one.');
    }

    var currentChunk = <T>[];
    for (final current in this) {
      currentChunk.add(current);
      if (currentChunk.length >= size) {
        yield currentChunk;
        currentChunk = <T>[];
      }
    }
    if (currentChunk.isNotEmpty) {
      yield currentChunk;
    }
  }
}
