import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
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
    ],
  );
}
