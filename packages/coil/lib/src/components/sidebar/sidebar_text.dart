import 'package:flutter/widgets.dart';

/// The text of a [Text] or [RichText] [widget], for semantics; null for
/// any other widget, which then needs its own `semanticLabel`.
String? coilSidebarPlainText(Widget? widget) => switch (widget) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  RichText(:final text) => text.toPlainText(),
  _ => null,
};
