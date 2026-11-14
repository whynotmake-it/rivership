import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const tooltipEntry = CatalogEntry(
  slug: 'tooltip',
  title: 'Tooltip',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Names icon-only controls on hover, focus or Android long-press.',
  page: TooltipPage.new,
);

class TooltipPage extends StatelessWidget {
  const TooltipPage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Tooltip',
    summary: 'In a group, one bubble glides from button to button.',
    children: [
      DemoSection(
        title: 'Toolbar',
        child: CoilTooltipGroup(
          child: DemoWrap(
            children: [
              for (final (label, glyph) in const [
                ('Previous', CoilGlyph.chevronStart),
                ('Next', CoilGlyph.chevronEnd),
                ('Close', CoilGlyph.cross),
              ])
                CoilTooltip(
                  message: Text(label),
                  child: CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    onPressed: () {},
                    semanticLabel: label,
                    icon: CoilDrawnGlyph(glyph),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
