import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// An image from the catalog's own `assets/` folder that loads whether the
/// catalog runs as its own app or inside the aggregate example app.
///
/// Flutter bundles an asset a package declares under its plain path while
/// that package is the app, and under `packages/<package>/<path>` while it is
/// a dependency, so the key depends on which app is running. This provider
/// reads the asset manifest and picks whichever of the two the running app
/// bundled.
@immutable
class CatalogAsset extends AssetBundleImageProvider {
  /// An image at [path] inside the catalog package.
  const CatalogAsset(this.path);

  /// The path as the catalog's own pubspec declares it, such as
  /// `assets/images/dunes.jpg`.
  final String path;

  @override
  Future<AssetBundleImageKey> obtainKey(
    ImageConfiguration configuration,
  ) async {
    final bundle = configuration.bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final name = manifest.listAssets().contains(path)
        ? path
        : 'packages/coil_example/$path';
    return AssetBundleImageKey(bundle: bundle, name: name, scale: 1);
  }

  @override
  bool operator ==(Object other) => other is CatalogAsset && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'CatalogAsset("$path")';
}
