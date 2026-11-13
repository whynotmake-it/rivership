import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const buttonEntry = CatalogEntry(
  slug: 'button',
  title: 'Button',
  group: CatalogGroup.leafControls,
  summary: 'Five variants, icons, loading, selected and compact.',
  page: ButtonPage.new,
);

class ButtonPage extends StatefulWidget {
  const ButtonPage({super.key});

  @override
  State<ButtonPage> createState() => _ButtonPageState();
}

class _ButtonPageState extends State<ButtonPage> {
  var _saving = false;
  var _menuOpen = false;
  var _likes = 0;
  Timer? _saveTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _save() {
    setState(() => _saving = true);
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saving = false);
    });
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Button',
    summary:
        'Hover with a mouse, press with a finger, Tab to see the focus ring. '
        'Pressing shrinks the fill 1 px per side; nothing scales.',
    children: [
      DemoSection(
        title: 'Variants',
        description:
            'One primary per view. Destructive is a tint, never solid red.',
        child: DemoWrap(
          children: [
            for (final variant in CoilButtonVariant.values)
              CoilButton(
                variant: variant,
                onPressed: () {},
                child: Text(_labelFor(variant)),
              ),
          ],
        ),
      ),
      DemoSection(
        title: 'With icons',
        description: 'Slots take any widget; icon-only buttons need a label.',
        child: DemoWrap(
          children: [
            CoilButton(
              leading: const CatalogIcon(Glyph.plus),
              onPressed: () {},
              child: const Text('New file'),
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              trailing: const CatalogIcon(Glyph.arrowRight),
              onPressed: () {},
              child: const Text('Continue'),
            ),
            CoilButton(
              variant: CoilButtonVariant.tertiary,
              leading: const CatalogIcon(Glyph.download),
              onPressed: () {},
              child: const Text('Export'),
            ),
            CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              icon: const CatalogIcon(Glyph.heart),
              semanticLabel: 'Like',
              onPressed: () => setState(() => _likes++),
            ),
            CoilButton.icon(
              variant: CoilButtonVariant.destructive,
              icon: const CatalogIcon(Glyph.trash),
              semanticLabel: 'Delete',
              onPressed: () {},
            ),
            if (_likes > 0)
              RoleText(
                '$_likes ${_likes == 1 ? 'like' : 'likes'}',
                role: TypeRole.caption,
                muted: true,
              ),
          ],
        ),
      ),
      DemoSection(
        title: 'States',
        description:
            'Loading locks the width and swaps the leading slot for a '
            'spinner. Selected holds the pressed look, for a menu trigger '
            'while its menu shows.',
        child: DemoWrap(
          children: [
            CoilButton(
              loading: _saving,
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving' : 'Save changes'),
            ),
            CoilButton(
              variant: CoilButtonVariant.tertiary,
              selected: _menuOpen,
              onPressed: () => setState(() => _menuOpen = !_menuOpen),
              child: Text(_menuOpen ? 'Menu open' : 'Open menu'),
            ),
            const CoilButton(onPressed: null, child: Text('Disabled')),
            const CoilButton(
              variant: CoilButtonVariant.tertiary,
              onPressed: null,
              child: Text('Disabled'),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Compact',
        description: 'One step denser, for toolbars and filter bars.',
        child: DemoWrap(
          children: [
            for (final variant in CoilButtonVariant.values)
              CoilButton(
                size: CoilSize.compact,
                variant: variant,
                onPressed: () {},
                child: Text(_labelFor(variant)),
              ),
            CoilButton.icon(
              size: CoilSize.compact,
              variant: CoilButtonVariant.ghost,
              icon: const CatalogIcon(Glyph.search),
              semanticLabel: 'Search',
              onPressed: () {},
            ),
          ],
        ),
      ),
    ],
  );

  static String _labelFor(CoilButtonVariant variant) => switch (variant) {
    CoilButtonVariant.primary => 'Publish',
    CoilButtonVariant.secondary => 'Duplicate',
    CoilButtonVariant.tertiary => 'Cancel',
    CoilButtonVariant.ghost => 'Skip',
    CoilButtonVariant.destructive => 'Delete project',
  };
}
