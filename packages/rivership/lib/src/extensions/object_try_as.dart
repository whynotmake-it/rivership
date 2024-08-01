/// Extension on [Object] that provides a [tryAs] method to safely cast an
/// object to a specified type.
extension ObjectTryAs on Object {
  /// Attempts to cast this object to [T].
  ///
  /// If the cast fails, returns null.
  ///
  /// Example usage:
  /// ```dart
  /// Object obj = 'Hello';
  /// String? str = obj.tryAs<String>();
  /// print(str); // Output: Hello
  /// ```
  T? tryAs<T>() {
    try {
      return this as T;
    } catch (_) {
      return null;
    }
  }
}
