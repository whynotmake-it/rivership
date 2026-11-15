import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const commandMenuEntry = CatalogEntry(
  slug: 'command-menu',
  title: 'CommandMenu',
  group: CatalogGroup.menusAndOverlays,
  summary: 'A searchable list of commands in a modal.',
  page: CommandMenuPage.new,
);

class CommandMenuPage extends StatelessWidget {
  const CommandMenuPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'CommandMenu',
    summary: 'Bind it to ⌘K near the root of your app.',
    children: [
      DemoSection(
        title: 'Open',
        child: DemoWrap(
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => showCoilCommandMenu(
                context: context,
                entries: [
                  const CoilMenuLabel(Text('Go to')),
                  for (final page in ['Inbox', 'Projects', 'Settings'])
                    CoilAction(
                      label: Text(page),
                      searchText: page,
                      onPressed: () {},
                    ),
                  const CoilMenuLabel(Text('Actions')),
                  CoilAction(
                    label: const Text('New project'),
                    searchText: 'New project',
                    shortcut: const Text('⌘N'),
                    onPressed: () {},
                  ),
                  CoilAction(
                    label: const Text('Invite people'),
                    searchText: 'Invite people',
                    onPressed: () {},
                  ),
                ],
              ),
              child: const Text('Command menu'),
            ),
          ],
        ),
      ),
    ],
  );
}
