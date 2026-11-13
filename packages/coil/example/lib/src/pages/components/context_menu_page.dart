import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const contextMenuEntry = CatalogEntry(
  slug: 'context-menu',
  title: 'ContextMenu',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Right-click, Control-click, Shift+F10 or long-press.',
  page: ContextMenuPage.new,
);

class ContextMenuPage extends StatelessWidget {
  const ContextMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    return CatalogPage(
      title: 'ContextMenu',
      summary:
          'Opens at the pointer. A long press lifts the item under the '
          'finger with a haptic.',
      children: [
        DemoSection(
          title: 'Area',
          child: CoilContextMenu(
            entries: [
              CoilAction(label: 'Copy', onPressed: () {}),
              CoilAction(label: 'Paste', onPressed: () {}),
              const CoilMenuSeparator(),
              CoilAction(
                label: 'Delete',
                tone: CoilActionTone.destructive,
                onPressed: () {},
              ),
            ],
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: theme.colors.muted,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const SizedBox(
                height: 140,
                child: Center(child: Text('Right-click or long-press here')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
