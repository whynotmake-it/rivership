/// Extension on the [Duration] class to provide formatting methods.
extension DurationFormatting on Duration {
  /// Converts the duration to a string representation in the format HH:MM:SS.
  String toStringHHMMSS() =>
      _prefix + toString().replaceAll("-", "").split('.').first.padLeft(8, "0");

  /// Converts the duration to a string representation in the format MM:SS.
  String toStringMMSS() {
    final hhmmss = toStringHHMMSS();
    return "$_prefix${hhmmss.substring(hhmmss.length - 5)}";
  }

  /// Converts the duration to a string representation in the format M:SS.
  String toStringMSS() {
    final mmss = toStringMMSS().replaceAll("-", "");
    final trimmed = mmss.startsWith("0") ? mmss.substring(1) : mmss;
    return _prefix + trimmed;
  }

  String get _prefix => isNegative ? "-" : "";
}
