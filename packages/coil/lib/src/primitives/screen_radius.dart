/// @docImport 'package:coil/src/primitives/drawer.dart';
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:corner_radius_plugin/corner_radius_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The corner radii of the device's screen, for a surface that moves away
/// from the screen's edges and should keep the screen's shape, such as the
/// page a reveal [CoilDrawer] pushes aside.
///
/// The radii come from `corner_radius_plugin`, the one place Coil reads
/// them: Android 12+ reports them through `RoundedCorner`, iOS 26+ through
/// UIKit's corner configuration, and older iPhones and iPads through a
/// bundled table of device bezels. Asking is asynchronous and happens once
/// per app, on first use. Until it answers, and wherever there is nothing
/// to ask (web, desktop, tests without a mocked channel, a failed query),
/// [value] is null and callers use their own fallback. A query that finds
/// nothing runs once more on the next read, in case it ran too early.
///
/// Answers the plugin can't vouch for count as unknown: a device missing
/// from its table, and any radius above [maxPlausibleRadius] or a quarter
/// of the screen's shortest side (Android before 12 reports physical
/// pixels). Only Android tells a square screen apart; it answers
/// [BorderRadius.zero].
///
/// Values are logical pixels per physical corner, in the screen's portrait
/// orientation.
abstract final class CoilScreenRadius {
  static final _notifier = ValueNotifier<BorderRadius?>(null);
  static Future<BorderRadius?>? _request;

  /// How many times the query has run without an answer.
  static int _attempts = 0;

  /// How many times a query that finds nothing may run: one retry, for a
  /// query that ran before the platform could answer (on Android, before
  /// the activity is attached).
  static const _maxAttempts = 2;

  /// The largest radius taken as real, in logical pixels.
  ///
  /// Phones today are about 24 to 56; anything past this is a wrong unit
  /// (the plugin's pre-Android 12 path reports physical pixels) or garbage.
  static const maxPlausibleRadius = 64.0;

  /// What the plugin answers when it has nothing to report: Coil asks for
  /// a negative default so it can't be mistaken for a square screen.
  static const _unknown = -1.0;

  /// The screen's corner radii ([BorderRadius.zero] for a square screen),
  /// or null while unknown.
  ///
  /// Reading it starts the platform query if it hasn't run yet; listen to
  /// [listenable] to hear when it answers.
  static BorderRadius? get value {
    unawaited(resolve());
    return _notifier.value;
  }

  /// Notifies when the radii become known.
  ///
  /// Listening doesn't start the query; read [value] or call [resolve] for
  /// that.
  static ValueListenable<BorderRadius?> get listenable => _notifier;

  /// Asks the platform for the radii and completes with them (null when
  /// unknown).
  ///
  /// Later calls return the same future, except that a query that found
  /// nothing runs once more on the next call.
  static Future<BorderRadius?> resolve() => _request ??= _ask();

  /// Whether this platform can report its radii at all.
  static bool get _supported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.android => true,
        _ => false,
      };

  static Future<BorderRadius?> _ask() async {
    if (!_supported) return null;
    _attempts++;
    BorderRadius? radius;
    try {
      radius = _read(await CornerRadiusPlugin.init(defaultRadius: _unknown));
    } on Object {
      // No plugin registered (tests, an add-to-app host without it) or the
      // platform refused (asked too early): unknown.
      radius = null;
    }
    if (radius == null) {
      // Let the next read ask once more.
      if (_attempts < _maxAttempts) _request = null;
      return null;
    }
    return _notifier.value = radius;
  }

  /// The plugin's answer as radii, or null when it is unknown or
  /// implausible.
  static BorderRadius? _read(CornerRadius corners) {
    final values = [
      corners.topLeft,
      corners.topRight,
      corners.bottomLeft,
      corners.bottomRight,
    ];
    // Negative: the plugin had nothing to report (its default radius).
    if (values.any((value) => value.isNaN || value < 0)) return null;
    if (values.every((value) => value == 0)) {
      // Only Android tells a square screen apart (no `RoundedCorner`); on
      // iOS a zero means the device isn't in the plugin's table.
      return defaultTargetPlatform == TargetPlatform.android
          ? BorderRadius.zero
          : null;
    }
    final limit = math.min(maxPlausibleRadius, _shortestSide / 4);
    if (values.any((value) => value > limit)) return null;
    return BorderRadius.only(
      topLeft: Radius.circular(corners.topLeft),
      topRight: Radius.circular(corners.topRight),
      bottomLeft: Radius.circular(corners.bottomLeft),
      bottomRight: Radius.circular(corners.bottomRight),
    );
  }

  /// The screen's shortest side in logical pixels, or infinity before the
  /// first view has a size.
  static double get _shortestSide {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return double.infinity;
    final view = views.first;
    final side = view.physicalSize.shortestSide / view.devicePixelRatio;
    return side > 0 ? side : double.infinity;
  }

  /// Forgets the answer, so the next read asks again, or pins [value] for
  /// a test without a platform channel.
  @visibleForTesting
  static void debugReset({BorderRadius? value}) {
    _attempts = 0;
    _request = value == null ? null : SynchronousFuture(value);
    _notifier.value = value;
  }
}
