import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

/// A hook that returns a [DateFormat] instance for the current locale.
///
/// The [format] argument is a string that specifies the format of the date.
/// The [adaptTo24HourTime] argument is a boolean that specifies whether the
/// date format should be adapted to 24-hour time, depending on the current
/// [MediaQuery.alwaysUse24HourFormatOf] value.
DateFormat useDateFormat({
  required String format,
  bool adaptTo24HourTime = true,
}) {
  final context = useContext();
  final locale = Localizations.localeOf(context);
  final use24Hour =
      adaptTo24HourTime && MediaQuery.alwaysUse24HourFormatOf(context);

  final pattern = use24Hour ? format.replaceAll('j', 'H') : format;

  return useMemoized(
    () => DateFormat(pattern, locale.toLanguageTag()),
    [pattern, locale],
  );
}
