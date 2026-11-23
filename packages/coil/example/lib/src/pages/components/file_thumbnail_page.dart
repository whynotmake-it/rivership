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
  summary:
      'A square preview of an attached file that falls back to the file type, '
      'and can offer a remove button.',
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
        'A square tile that fills with the file’s preview image, and shows '
        'the file type instead while the image loads or when there is no '
        'preview to draw.',
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
        'The remove badge stays visible rather than waiting for a hover, and '
            'although it is drawn small it takes a 44 pixel hit target.',
      ),
      CatalogNote(
        'Motion',
        'The tile animates nothing by itself; once the image has loaded it '
            'fades in over the file type on the fade spring.',
      ),
      CatalogNote(
        'Accessibility',
        'A tile with an image is labelled with the file’s name, and one that '
            'is still waiting for its image announces "Loading preview".',
      ),
      CatalogNote(
        'Do / Don’t',
        'Previews that need rendering, such as a page of a PDF or a frame of '
            'a video, belong in the app: render them there and pass the '
            'result as image.',
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
            'Until the image arrives the tile keeps showing the file type '
            'next to a spinner.',
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
