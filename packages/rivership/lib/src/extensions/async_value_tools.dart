import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Useful helper methods on [AsyncValue]
extension AsyncValueTools<T> on AsyncValue<T> {
  /// Returns true when this [AsyncValue] is loading and has no previous value.
  bool get isLoadingInitial => isLoading && !hasValue && !hasError;

  /// Returns the most recent [value] of this [AsyncValue], ignoring any
  /// previous values.
  ///
  /// Behaves just like [AsyncValue.value], which means errors are rethrown.
  T? get newestValue => unwrapPrevious().value;

  /// Returns the most recent [valueOrNull] of this [AsyncValue], ignoring any
  /// previous values.
  ///
  /// Behaves just like [valueOrNull], which means errors are ignored and the
  /// value will be null in error and loading states.
  T? get newestValueOrNull => unwrapPrevious().valueOrNull;
}
