// What the composer examples share: a few files to attach, and the
// thumbnails that show them.
import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/catalog_asset.dart';
import 'package:flutter/widgets.dart';

/// A file a person can attach in the examples.
@immutable
class DemoFile {
  const DemoFile(this.name, {this.image});

  final String name;
  final ImageProvider? image;
}

const demoFiles = [
  DemoFile('dunes.jpg', image: CatalogAsset('assets/images/dunes.jpg')),
  DemoFile('brief.pdf'),
  DemoFile('notes.md'),
  DemoFile('budget.xlsx'),
];

/// The thumbnail for [file], with a remove button when [onRemove] is given.
Widget demoThumbnail(
  DemoFile file, {
  VoidCallback? onRemove,
  double dimension = 56,
}) => CoilFileThumbnail(
  key: ValueKey(file.name),
  name: file.name,
  image: file.image,
  dimension: dimension,
  onRemove: onRemove,
);

/// The next file that isn't attached yet, or null when all are.
DemoFile? nextDemoFile(List<DemoFile> attached) {
  for (final file in demoFiles) {
    if (!attached.contains(file)) return file;
  }
  return null;
}
