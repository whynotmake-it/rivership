import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Useful helper methods on [AsyncValue]
extension AsyncValueTools<T> on AsyncValue<T> {
  /// Returns true when this [AsyncValue] is loading and has no previous value.
  bool get isLoadingInitial => isLoading && !hasValue && !hasError;
}
