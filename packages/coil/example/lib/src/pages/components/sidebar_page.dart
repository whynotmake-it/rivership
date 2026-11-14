import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const sidebarEntry = CatalogEntry(
  slug: 'sidebar',
  title: 'Sidebar',
  group: CatalogGroup.shellAndComposites,
  summary: 'Folds away beside the page; a drawer on phones.',
  page: SidebarPage.new,
);

class SidebarPage extends StatefulWidget {
  const SidebarPage({super.key});

  @override
  State<SidebarPage> createState() => _SidebarPageState();
}

class _SidebarPageState extends State<SidebarPage> {
  var _page = 'Inbox';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Sidebar',
    summary: 'Ctrl+B or ⌘B toggles it while focus is inside.',
    children: [
      DemoSection(
        title: 'Scaffold',
        child: SizedBox(
          height: 360,
          child: CoilSidebarScaffold(
            width: 200,
            sidebar: CoilSidebar(
              children: [
                CoilSidebarGroup(
                  label: 'Mail',
                  child: CoilSidebarMenu(
                    items: [
                      for (final label in ['Inbox', 'Drafts', 'Sent'])
                        CoilSidebarItem(
                          label: label,
                          selected: _page == label,
                          onPressed: () => setState(() => _page = label),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            body: Builder(
              builder: (context) => Center(
                child: CoilButton(
                  variant: CoilButtonVariant.secondary,
                  onPressed: CoilSidebarScaffold.of(context).toggle,
                  child: const Text('Toggle'),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
