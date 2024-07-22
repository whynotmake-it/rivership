import 'package:flutter_test/flutter_test.dart';

/// Returns a matcher that matches if the [other] is a shuffled version
/// of the [Iterable] being matched.
///
/// Makes sure that all elements are present, but the order is not the same.
Matcher isShuffled<T>(Iterable<T> other) {
  return allOf(
    containsAll(other),
    hasLength(other.length),
    isNot(containsAllInOrder(other)),
  );
}
