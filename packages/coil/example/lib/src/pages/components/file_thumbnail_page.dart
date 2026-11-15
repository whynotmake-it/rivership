import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const fileThumbnailEntry = CatalogEntry(
  slug: 'file-thumbnail',
  title: 'FileThumbnail',
  group: CatalogGroup.shellAndComposites,
  summary: 'A square preview, or the file type, with an optional remove.',
  page: FileThumbnailPage.new,
);

class FileThumbnailPage extends StatelessWidget {
  const FileThumbnailPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'FileThumbnail',
    summary: 'Render previews (a PDF page, a video frame) in the app.',
    children: [
      DemoSection(
        title: 'Sizes',
        child: DemoWrap(
          children: [
            const CoilFileThumbnail(name: 'report.pdf', size: 40),
            const CoilFileThumbnail(name: 'budget.xlsx'),
            CoilFileThumbnail(name: 'slides.key', size: 72, onRemove: () {}),
          ],
        ),
      ),
      DemoSection(
        title: 'Images',
        description:
            'Pass any ImageProvider as image; it fills the square. Until it '
            'loads, or if it fails, the tile shows the file type.',
        child: DemoWrap(
          children: [
            CoilFileThumbnail(
              name: 'dunes.jpg',
              size: 72,
              image: const AssetImage('assets/images/dunes.jpg'),
              onRemove: () {},
            ),
            const CoilFileThumbnail(
              name: 'dunes.jpg',
              image: AssetImage('assets/images/dunes.jpg'),
            ),
            const CoilFileThumbnail(
              name: 'upload.png',
              size: 72,
              image: _StillLoading(),
            ),
          ],
        ),
      ),
    ],
  );
}

/// An image that never finishes loading, to show the placeholder a
/// thumbnail keeps while its image is on its way.
@immutable
class _StillLoading extends ImageProvider<_StillLoading> {
  const _StillLoading();

  @override
  Future<_StillLoading> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _StillLoading key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
