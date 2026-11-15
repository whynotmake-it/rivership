import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_devtools/motor_devtools.dart';

/// The standalone catalog app: a bare [WidgetsApp], since coil needs no
/// Material or Cupertino app shell, wrapped in [MotorDevTools] so every coil
/// animation can be inspected.
class CoilCatalogApp extends StatefulWidget {
  const CoilCatalogApp({super.key, this.settings, this.devTools = true});

  /// Settings to start from (tests pass them in).
  final CatalogSettings? settings;

  /// Whether to show the Motor devtools bubble.
  final bool devTools;

  @override
  State<CoilCatalogApp> createState() => _CoilCatalogAppState();
}

class _CoilCatalogAppState extends State<CoilCatalogApp> {
  late final _router = RootStackRouter.build(
    routes: [coilCatalogRoute(path: '/')],
  );
  late final _ownSettings = CatalogSettings();

  CatalogSettings get _settings => widget.settings ?? _ownSettings;

  @override
  void dispose() {
    _router.dispose();
    _ownSettings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = WidgetsApp.router(
      title: 'coil',
      color: CoilColors.light.brand,
      debugShowCheckedModeBanner: false,
      routerConfig: _router.config(),
    );
    return CatalogSettingsScope(
      settings: _settings,
      child: MotorDevTools(
        // The catalog ships the inspector on purpose, in release builds too.
        enabled: widget.devTools,
        child: app,
      ),
    );
  }
}
