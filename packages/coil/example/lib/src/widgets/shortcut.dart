import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// Whether the previewed platform uses ⌘ for shortcuts.
bool usesCommandKey(BuildContext context) =>
    switch (CoilTheme.platformOf(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };

/// The text of a shortcut for [CoilKbd] on the previewed platform: `⌘K` on
/// Apple platforms, `Ctrl+K` elsewhere.
String shortcutOf(BuildContext context, String key, {bool shift = false}) =>
    usesCommandKey(context)
    ? '${shift ? '⇧' : ''}⌘$key'
    : 'Ctrl+${shift ? 'Shift+' : ''}$key';
