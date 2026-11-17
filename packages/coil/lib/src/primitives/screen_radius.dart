import 'dart:async';

import 'package:corner_radius_plugin/corner_radius_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The corner radii of the device's screen, for a surface that moves away
/// from the screen's edges and should keep the screen's shape, such as the
/// page a reveal `CoilDrawer` pushes aside.
///
/// The radii come from `corner_radius_plugin`, the one place coil reads
/// them: Android 12+ reports them through `RoundedCorner`, iOS 26+ through
/// UIKit's corner configuration, and older iPhones and iPads through a
/// bundled table of device bezels. Asking is asynchronous and happens once
/// per app, on first use. Until it answers, and wherever there is nothing
/// to ask (web, desktop, tests without a mocked channel, a failed query),
/// [value] is null and callers use their own fallback. A square screen
/// answers [BorderRadius.zero].
///
/// Values are logical pixels per physical corner, in the screen's portrait
/// orientation.
abstract final class CoilScreenRadius {
  static final _notifier = ValueNotifier<BorderRadius?>(null);
  static Future<BorderRadius?>? _request;

  /// The screen's corner radii ([BorderRadius.zero] for a square screen),
  /// or null while unknown.
  ///
  /// Reading it starts the platform query if it hasn't run yet; listen to
  /// [listenable] to hear when it answers.
  static BorderRadius? get value {
    unawaited(resolve());
    return _notifier.value;
  }

  /// Notifies when the radii become known. Listening doesn't start the
  /// query; read [value] or call [resolve] for that.
  static ValueListenable<BorderRadius?> get listenable => _notifier;

  /// Asks the platform for the radii, once, and completes with them (null
  /// when unknown). Later calls return the same future.
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
    try {
      final corners = await CornerRadiusPlugin.init();
      final radius = BorderRadius.only(
        topLeft: Radius.circular(corners.topLeft),
        topRight: Radius.circular(corners.topRight),
        bottomLeft: Radius.circular(corners.bottomLeft),
        bottomRight: Radius.circular(corners.bottomRight),
      );
      return _notifier.value = radius;
    } on Object {
      // No plugin registered (tests, an add-to-app host without it) or the
      // platform refused: there is nothing better than the fallback.
      return null;
    }
  }

  /// Forgets the answer, so the next read asks again, or pins [value] for
  /// a test without a platform channel.
  @visibleForTesting
  static void debugReset({BorderRadius? value}) {
    _request = value == null ? null : SynchronousFuture(value);
    _notifier.value = value;
  }
}
