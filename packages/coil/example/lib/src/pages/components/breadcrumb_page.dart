import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const breadcrumbEntry = CatalogEntry(
  slug: 'breadcrumb',
  title: 'Breadcrumb',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Where a page sits; long trails fold into a menu.',
  page: BreadcrumbPage.new,
);

class BreadcrumbPage extends StatelessWidget {
  const BreadcrumbPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Breadcrumb',
    summary: 'The current page is the last crumb and not a link.',
    children: [
      DemoSection(
        title: 'Trail',
        child: CoilBreadcrumb(
          crumbs: [
            for (final label in ['Home', 'Projects', 'Coil', 'Design'])
              CoilCrumb(label: label, onPressed: () {}),
            const CoilCrumb(label: 'Tokens'),
          ],
        ),
      ),
    ],
  );
}
