import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const typeEntry = CatalogEntry(
  slug: 'type',
  title: 'Type',
  group: CatalogGroup.foundations,
  summary:
      'Seven text roles per tier, set in whichever font you choose, such as '
      'Allo or Inter.',
  page: TypePage.new,
);

class TypePage extends StatelessWidget {
  const TypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tier = CoilTheme.tierOf(context);
    final family =
        CoilTheme.textOf(context).body.fontFamily ?? "the platform's font";
    return CatalogPage(
      title: 'Type',
      summary:
          'The roles of CoilTypography at the current tier (${tier.name}), '
          'set in $family. Change the font, its roundness and its features '
          'under Type in the settings.',
      children: [
        for (final size in CoilSize.values)
          DemoSection(
            title: size == CoilSize.regular ? 'Regular' : 'Compact',
            child: CoilAdaptiveScope(
              size: size,
              child: const _Roles(),
            ),
          ),
        const DemoSection(
          title: 'Weights',
          description:
              "Weights are plain FontWeights, which set a variable font's "
              'wght axis. Titles and selected labels share one emphasis '
              'weight, so it follows the font.',
          child: _Weights(),
        ),
        const DemoSection(
          title: 'Optical size',
          description:
              'Each role sets optical size (opsz) to match its font size, '
              'just like CSS. Small text gets wider letter spacing while '
              'titles tighten up. On the right, every size is pinned to '
              'standard body proportions (opsz 14).',
          child: _OpticalSize(),
        ),
        const DemoSection(
          title: 'Tabular figures',
          description:
              'Numbers that line up use tabular figures (.tabular); prose '
              'keeps proportional ones.',
          child: _Figures(),
        ),
      ],
    );
  }
}

class _Roles extends StatelessWidget {
  const _Roles();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return DemoColumn(
      spacing: 12,
      children: [
        for (final (name, style) in [
          ('display', text.display),
          ('title', text.title),
          ('subtitle', text.subtitle),
          ('body', text.body),
          ('field', text.field),
          ('caption', text.caption),
          ('micro', text.micro),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name · ${_n(style.fontSize!)}/${_n(style.lineHeight)} · '
                '${style.fontWeight?.value ?? 400}',
                style: text.muted.micro,
              ),
              const SizedBox(height: 2),
              Text('Clear, readable type at every size', style: style),
            ],
          ),
      ],
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _Weights extends StatelessWidget {
  const _Weights();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return DemoColumn(
      spacing: 8,
      children: [
        for (final (name, weight) in [
          ('normal', FontWeight.w400),
          ('emphasis', text.emphasis),
          ('bold', FontWeight.w700),
        ])
          Text(
            '$name · ${weight.value}',
            style: text.title.copyWith(fontWeight: weight),
          ),
      ],
    );
  }
}

class _OpticalSize extends StatelessWidget {
  const _OpticalSize();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    TextStyle textCut(TextStyle style) => style.copyWith(
      fontVariations: [
        for (final axis in [...?style.fontVariations])
          if (axis.axis != 'opsz') axis,
        const FontVariation('opsz', 14),
      ],
    );
    Widget column(TextStyle Function(TextStyle) adjust) => DemoColumn(
      spacing: 8,
      children: [
        for (final style in [text.micro, text.body, text.title, text.display])
          Text('Handgloves 0123', style: adjust(style)),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Labeled('Automatic', child: column((s) => s))),
        Expanded(child: Labeled('Fixed (14)', child: column(textCut))),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures();

  @override
  Widget build(BuildContext context) {
    final style = CoilTheme.textOf(context).body;
    return Row(
      children: [
        Expanded(
          child: Labeled(
            'Proportional',
            child: Text('1,111.11\n9,999.99\n4,041.70', style: style),
          ),
        ),
        Expanded(
          child: Labeled(
            'Tabular',
            child: Text('1,111.11\n9,999.99\n4,041.70', style: style.tabular),
          ),
        ),
      ],
    );
  }
}
