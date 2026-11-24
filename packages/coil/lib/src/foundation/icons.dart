/// @docImport 'package:coil/src/components/banner/banner.dart';
/// @docImport 'package:coil/src/components/select/select.dart';
/// @docImport 'package:coil/src/foundation/theme.dart';
/// @docImport 'package:coil/src/primitives/icon_presence.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Marks a copyWith argument that wasn't passed.
const Object _keep = Object();

/// A role an icon plays in Coil's components, named for what it means,
/// not for its shape.
///
/// Each value corresponds to a field of [CoilIcons].
enum CoilIconRole {
  /// Checked, picked, or copied: a checkbox's tick, a select's checkmark,
  /// a menu's check, or a copy that worked.
  check,

  /// Indeterminate: a checkbox that is partly checked.
  dash,

  /// Copy to the clipboard, at rest.
  copy,

  /// A refused action: a copy that failed.
  failed,

  /// Close or remove: a sheet's and a dialog's close button, a banner's or
  /// card's dismiss, or a chip's or attachment's remove.
  close,

  /// A field's error.
  alert,

  /// Toward the start: back, previous month, or page.
  ///
  /// Left in LTR, right in RTL.
  chevronStart,

  /// Toward the end: next month or page, a submenu, a breadcrumb separator,
  /// or a disclosure (turned a quarter when it opens).
  ///
  /// Right in LTR, left in RTL.
  chevronEnd,

  /// Opens downward or sorts descending: a select's and a combobox's
  /// indicator, the calendar's month title, or a pile's collapse button.
  chevronDown,

  /// Sorts ascending.
  chevronUp,

  /// Send a message.
  send,

  /// Stop a reply that is streaming.
  stop,
}

/// The icons Coil's components show, by [CoilIconRole], for an app that
/// brings its own icon set ([CoilThemeData.icons]).
///
/// Each field is any widget, styled like a slot by the ambient [IconTheme]
/// (size, color, `weight`, `applyTextScaling`): an [Icon] from an icon
/// font, an SVG, or a painter. Null keeps Coil's drawn glyph, so a partial set
/// replaces only the roles it names. A widget passed to a component's own
/// slot ([CoilSelect.checkmark], [CoilBanner.dismissIcon]) still wins over
/// this map.
///
/// Where a component animates an icon (a checkbox's tick, the copy
/// feedback, the composer's send and stop), it wraps it in a
/// [CoilIconPresence]: an icon that reads it animates itself, and any other
/// fades and scales in and out.
///
/// The chevrons are named by direction in the text: Coil's drawn
/// [chevronStart] and [chevronEnd] mirror in RTL, and a custom one should
/// too (`Icon(…, matchTextDirection: true)`).
///
/// ```dart
/// CoilThemeData(
///   icons: CoilIcons(
///     check: Icon(LucideIcons.check),
///     close: Icon(LucideIcons.x),
///   ),
/// )
/// ```
///
/// See doc/icons.md for complete sets.
@immutable
class CoilIcons with Diagnosticable {
  /// Creates an icon set; unset roles keep Coil's drawn glyphs.
  const CoilIcons({
    this.check,
    this.dash,
    this.copy,
    this.failed,
    this.close,
    this.alert,
    this.chevronStart,
    this.chevronEnd,
    this.chevronDown,
    this.chevronUp,
    this.send,
    this.stop,
  });

  /// See [CoilIconRole.check].
  final Widget? check;

  /// See [CoilIconRole.dash].
  final Widget? dash;

  /// See [CoilIconRole.copy].
  final Widget? copy;

  /// See [CoilIconRole.failed].
  final Widget? failed;

  /// See [CoilIconRole.close].
  final Widget? close;

  /// See [CoilIconRole.alert].
  final Widget? alert;

  /// See [CoilIconRole.chevronStart].
  final Widget? chevronStart;

  /// See [CoilIconRole.chevronEnd].
  final Widget? chevronEnd;

  /// See [CoilIconRole.chevronDown].
  final Widget? chevronDown;

  /// See [CoilIconRole.chevronUp].
  final Widget? chevronUp;

  /// See [CoilIconRole.send].
  final Widget? send;

  /// See [CoilIconRole.stop].
  final Widget? stop;

  /// The icon for [role], or null for Coil's drawn glyph.
  Widget? operator [](CoilIconRole role) => switch (role) {
    CoilIconRole.check => check,
    CoilIconRole.dash => dash,
    CoilIconRole.copy => copy,
    CoilIconRole.failed => failed,
    CoilIconRole.close => close,
    CoilIconRole.alert => alert,
    CoilIconRole.chevronStart => chevronStart,
    CoilIconRole.chevronEnd => chevronEnd,
    CoilIconRole.chevronDown => chevronDown,
    CoilIconRole.chevronUp => chevronUp,
    CoilIconRole.send => send,
    CoilIconRole.stop => stop,
  };

  /// Returns a copy with the given roles replaced.
  ///
  /// Pass null for a role to go back to Coil's drawn glyph.
  CoilIcons copyWith({
    Object? check = _keep,
    Object? dash = _keep,
    Object? copy = _keep,
    Object? failed = _keep,
    Object? close = _keep,
    Object? alert = _keep,
    Object? chevronStart = _keep,
    Object? chevronEnd = _keep,
    Object? chevronDown = _keep,
    Object? chevronUp = _keep,
    Object? send = _keep,
    Object? stop = _keep,
  }) {
    Widget? pick(Object? value, Widget? current) =>
        identical(value, _keep) ? current : value as Widget?;
    return CoilIcons(
      check: pick(check, this.check),
      dash: pick(dash, this.dash),
      copy: pick(copy, this.copy),
      failed: pick(failed, this.failed),
      close: pick(close, this.close),
      alert: pick(alert, this.alert),
      chevronStart: pick(chevronStart, this.chevronStart),
      chevronEnd: pick(chevronEnd, this.chevronEnd),
      chevronDown: pick(chevronDown, this.chevronDown),
      chevronUp: pick(chevronUp, this.chevronUp),
      send: pick(send, this.send),
      stop: pick(stop, this.stop),
    );
  }

  /// This set with [other]'s icons on top: a role [other] names wins, the
  /// rest keep this set's.
  CoilIcons merge(CoilIcons? other) {
    if (other == null) return this;
    return CoilIcons(
      check: other.check ?? check,
      dash: other.dash ?? dash,
      copy: other.copy ?? copy,
      failed: other.failed ?? failed,
      close: other.close ?? close,
      alert: other.alert ?? alert,
      chevronStart: other.chevronStart ?? chevronStart,
      chevronEnd: other.chevronEnd ?? chevronEnd,
      chevronDown: other.chevronDown ?? chevronDown,
      chevronUp: other.chevronUp ?? chevronUp,
      send: other.send ?? send,
      stop: other.stop ?? stop,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoilIcons &&
      CoilIconRole.values.every((role) => other[role] == this[role]);

  @override
  int get hashCode => Object.hashAll(CoilIconRole.values.map((r) => this[r]));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    for (final role in CoilIconRole.values) {
      properties.add(
        DiagnosticsProperty<Widget>(role.name, this[role], defaultValue: null),
      );
    }
  }
}
