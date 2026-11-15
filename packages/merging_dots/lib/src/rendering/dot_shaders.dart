import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads and caches the fragment programs that render merging dots.
///
/// The programs load on first use, and until they are ready dots are drawn
/// as plain circles. Call [precache] early, for example in `main`, so the
/// very first frame already merges.
abstract final class DotShaders {
  static const _package = 'packages/merging_dots/';

  static Future<ui.FragmentProgram> _load(String name) async {
    final asset = 'shaders/$name.frag';
    try {
      return await ui.FragmentProgram.fromAsset('$_package$asset');
    } on Exception {
      // Inside this package itself, like in its own tests, assets aren't
      // prefixed with the package.
      return ui.FragmentProgram.fromAsset(asset);
    }
  }

  static ui.FragmentProgram? _grid;
  static ui.FragmentProgram? _cloud;
  static ui.FragmentProgram? _tiles;
  static Future<void>? _loading;

  /// The grid program, or null while it loads.
  static ui.FragmentProgram? get grid => _grid;

  /// The cloud program, or null while it loads.
  static ui.FragmentProgram? get cloud => _cloud;

  /// The tiles program, or null while it loads.
  static ui.FragmentProgram? get tiles => _tiles;

  /// Whether all programs are ready.
  static bool get isLoaded => _grid != null && _cloud != null && _tiles != null;

  /// Loads all programs. Completes right away once they are loaded.
  static Future<void> precache() {
    return _loading ??= () async {
      try {
        final (grid, cloud, tiles) = await (
          _load('dot_grid'),
          _load('dot_cloud'),
          _load('dot_tiles'),
        ).wait;
        _grid = grid;
        _cloud = cloud;
        _tiles = tiles;
      } on Object catch (error, stack) {
        // Leave the circle fallback in place, but tell the developer.
        _loading = null;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'merging_dots',
            context: ErrorDescription('while loading the merging dots shaders'),
          ),
        );
      }
    }();
  }
}
