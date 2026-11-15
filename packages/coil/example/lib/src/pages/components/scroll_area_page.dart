import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const scrollAreaEntry = CatalogEntry(
  slug: 'scroll-area',
  title: 'ScrollArea',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A scroller with a slim thumb and edges that fade.',
  page: ScrollAreaPage.new,
);

class ScrollAreaPage extends StatelessWidget {
  const ScrollAreaPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'ScrollArea',
    summary: 'The thumb shows while scrolling and on hover.',
    children: [
      DemoSection(
        title: 'List',
        child: SizedBox(
          height: 200,
          child: CoilScrollArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 1; i <= 30; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Item $i'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
