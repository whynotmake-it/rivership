import 'dart:async';
import 'dart:convert';

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Below this window width the gallery uses Coil's touch tier.
const turnsPhoneBreakpoint = 600.0;

/// Sets up Coil for the turns gallery: the theme (inheriting an ancestor
/// [CoilTheme] when mounted inside `apps/example`), an optional light/dark
/// override, the touch tier in narrow windows, and the page background.
class TurnsEnvironment extends StatefulWidget {
  const TurnsEnvironment({
    required this.child,
    this.brightnessOverride,
    super.key,
  });

  final Widget child;

  /// Forces light or dark colors when non-null; null follows the ambient
  /// [CoilTheme] or platform brightness.
  final Brightness? brightnessOverride;

  @override
  State<TurnsEnvironment> createState() => _TurnsEnvironmentState();
}

class _TurnsEnvironmentState extends State<TurnsEnvironment> {
  static Future<bool>? _alloBundled;

  static Future<bool> _loadAlloBundled() async {
    try {
      final manifest = await rootBundle.loadString('FontManifest.json');
      final families = jsonDecode(manifest) as List<Object?>;
      return families.any(
        (family) => family is Map && family['family'] == 'Allo',
      );
    } on Object {
      return false;
    }
  }

  var _allo = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      (_alloBundled ??= _loadAlloBundled()).then((bundled) {
        if (mounted && bundled != _allo) setState(() => _allo = bundled);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Builder(
      builder: (context) => ColoredBox(
        color: CoilTheme.of(context).colors.background,
        child: DefaultTextStyle(
          style: CoilTheme.textOf(context).body,
          child: widget.child,
        ),
      ),
    );
    if (MediaQuery.sizeOf(context).width < turnsPhoneBreakpoint) {
      result = CoilAdaptiveScope(tier: CoilTier.touch, child: result);
    }

    final brightnessOverride = widget.brightnessOverride;
    if (context.findAncestorWidgetOfExactType<CoilTheme>() != null) {
      // Always the same wrapper, so toggling the override doesn't remount the
      // gallery (and its router) below.
      return CoilTheme.override(
        transform: (parent) => switch (brightnessOverride) {
          null => parent,
          Brightness.dark => parent.copyWith(colors: CoilColors.dark),
          Brightness.light => parent.copyWith(colors: CoilColors.light),
        },
        child: result,
      );
    }

    final dark =
        (brightnessOverride ?? MediaQuery.platformBrightnessOf(context)) ==
        Brightness.dark;
    return CoilTheme(
      data: (dark ? CoilThemeData.dark : CoilThemeData.light).copyWith(
        typography: _allo ? CoilTypography.allo() : CoilTypography.platform,
      ),
      child: result,
    );
  }
}
