import 'package:coil_example/src/shell/settings.dart';
import 'package:flutter/widgets.dart';

/// Applies the catalog's [CatalogSettings] to [child], the catalog's
/// navigator, so every page and overlay sees them. Uses the settings of an
/// enclosing [CatalogSettingsScope], or owns a set when mounted inside
/// another app.
class CatalogShell extends StatefulWidget {
  const CatalogShell({required this.child, super.key});

  final Widget child;

  @override
  State<CatalogShell> createState() => _CatalogShellState();
}

class _CatalogShellState extends State<CatalogShell> {
  CatalogSettings? _ownSettings;

  @override
  void dispose() {
    _ownSettings?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final environment = CatalogEnvironment(child: widget.child);
    if (CatalogSettingsScope.maybeOf(context) != null) return environment;
    return CatalogSettingsScope(
      settings: _ownSettings ??= CatalogSettings(),
      child: environment,
    );
  }
}
