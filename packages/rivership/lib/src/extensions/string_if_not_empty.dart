/// Extension on [String] to return the string if it is not empty, otherwise
/// returns null.
extension StringIfNotEmpty on String {
  /// Returns the string if it is not empty, otherwise returns null.
  String? ifNotEmpty() => isEmpty ? null : this;
}
