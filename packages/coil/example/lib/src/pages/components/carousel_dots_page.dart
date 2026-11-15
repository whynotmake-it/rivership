import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const carouselDotsEntry = CatalogEntry(
  slug: 'carousel-dots',
  title: 'CarouselDots',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Page dots whose active pill stretches between pages.',
  page: CarouselDotsPage.new,
);

class CarouselDotsPage extends StatefulWidget {
  const CarouselDotsPage({super.key});

  @override
  State<CarouselDotsPage> createState() => _CarouselDotsPageState();
}

class _CarouselDotsPageState extends State<CarouselDotsPage> {
  var _page = 0;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'CarouselDots',
    summary: 'Tap a dot, or focus them and use the arrow keys.',
    children: [
      DemoSection(
        title: 'Five pages',
        child: Center(
          child: CoilCarouselDots(
            count: 5,
            value: _page,
            onChanged: (v) => setState(() => _page = v),
          ),
        ),
      ),
    ],
  );
}
