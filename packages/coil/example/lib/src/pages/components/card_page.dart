import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const cardEntry = CatalogEntry(
  slug: 'card',
  title: 'Card',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Surfaces with a title, media and an optional press or dismiss.',
  page: CardPage.new,
);

class CardPage extends StatelessWidget {
  const CardPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Card',
    summary: 'Cards in a group share one hover highlight.',
    children: [
      DemoSection(
        title: 'Group',
        child: CoilCardGroup(
          children: [
            for (final (title, description) in const [
              ('Starter', 'For trying things out.'),
              ('Team', 'Shared projects and roles.'),
            ])
              CoilCard(
                title: Text(title),
                description: Text(description),
                onPressed: () {},
              ),
          ],
        ),
      ),
    ],
  );
}
