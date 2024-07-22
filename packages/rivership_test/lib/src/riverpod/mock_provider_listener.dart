import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

/// Can be used to listen to a [Provider] and verify interactions using
/// mocktail.
class MockProviderListener<T> extends Mock {
  /// Should be called in `ref.listen`, so that then all calls can be verified
  /// using mocktail syntax.
  void call(T? previous, T next);
}
