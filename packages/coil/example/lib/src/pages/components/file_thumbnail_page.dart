import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/composer_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const fileThumbnailEntry = CatalogEntry(
  slug: 'file-thumbnail',
  title: 'FileThumbnail',
  group: CatalogGroup.shellAndComposites,
  summary: 'A square preview, or the file type, with an optional remove.',
  page: FileThumbnailPage.new,
);

class FileThumbnailPage extends StatefulWidget {
  const FileThumbnailPage({super.key});

  @override
  State<FileThumbnailPage> createState() => _FileThumbnailPageState();
}

class _FileThumbnailPageState extends State<FileThumbnailPage> {
  var _dimension = 72.0;
  var _image = true;
  var _removable = true;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'FileThumbnail',
    summary:
        'A square preview that fills with the image and falls back to the '
        'file type while it loads or when there is nothing to draw.',
    hero: const _Attachments(),
    usage: '''
CoilFileThumbnail(
  name: 'dunes.jpg',
  image: const AssetImage('assets/images/dunes.jpg'),
  dimension: 72,
  onRemove: () => setState(() => files.remove(file)),
)''',
    notes: const [
      CatalogNote(
        'Touch',
        'The remove badge is always visible. It is drawn small but takes a '
            '44 hit target.',
      ),
      CatalogNote(
        'Motion',
        'The thumbnail has none of its own; an image fades in on fade once '
            'it has loaded, over the file type.',
      ),
      CatalogNote(
        'Accessibility',
        'An image is labeled with the file name. A thumbnail still loading '
            'announces "Loading preview".',
      ),
      CatalogNote(
        'Do / Don’t',
        'Render previews that need an engine, such as a PDF page or a video '
            'frame, in the app and pass the result as image.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Size',
              value: _dimension,
              values: const [40.0, 56.0, 72.0, 96.0],
              labelOf: (v) => '${v.round()}',
              onChanged: (v) => setState(() => _dimension = v),
            ),
            DemoControl.toggle(
              label: 'Image',
              value: _image,
              onChanged: (v) => setState(() => _image = v),
            ),
            DemoControl.toggle(
              label: 'Removable',
              value: _removable,
              onChanged: (v) => setState(() => _removable = v),
            ),
          ],
        ),
        child: DemoWrap(
          children: [
            for (final file in demoFiles)
              CoilFileThumbnail(
                name: file.name,
                dimension: _dimension,
                image: _image ? file.image : null,
                onRemove: _removable ? () {} : null,
              ),
          ],
        ),
      ),
      const DemoSection(
        title: 'Still loading',
        description:
            'Until the image arrives, the tile keeps its file type and a '
            'spinner.',
        child: DemoWrap(
          children: [
            CoilFileThumbnail(
              name: 'upload.png',
              dimension: 72,
              image: _StillLoading(),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A message's attachments: files can be added and taken away again.
class _Attachments extends StatefulWidget {
  const _Attachments();

  @override
  State<_Attachments> createState() => _AttachmentsState();
}

class _AttachmentsState extends State<_Attachments> {
  var _files = [demoFiles[0], demoFiles[1]];

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final next = nextDemoFile(_files);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Attachments', style: text.title)),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              onPressed: next == null
                  ? null
                  : () => setState(() => _files = [..._files, next]),
              child: const Text('Add file'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _files.isEmpty
              ? 'Nothing attached.'
              : '${_files.length} of ${demoFiles.length} files attached.',
          style: text.muted.caption,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final file in _files)
              SizedBox(
                width: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    demoThumbnail(
                      file,
                      dimension: 88,
                      onRemove: () =>
                          setState(() => _files = [..._files]..remove(file)),
                    ),
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.muted.caption,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
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
