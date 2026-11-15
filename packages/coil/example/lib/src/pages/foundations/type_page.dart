import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const typeEntry = CatalogEntry(
  slug: 'type',
  title: 'Type',
  group: CatalogGroup.foundations,
  summary: 'Inter Variable: seven roles per tier, three weights.',
  page: TypePage.new,
);

class TypePage extends StatelessWidget {
  const TypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tier = CoilTheme.tierOf(context);
    return CatalogPage(
      title: 'Type',
      summary:
          'Roles at the current tier (${tier.name}). Switch the tier or the '
          'text scale in the settings to compare.',
      children: [
        for (final size in CoilSize.values)
          DemoSection(
            title: size == CoilSize.regular ? 'Regular' : 'Compact',
            child: DemoColumn(
              spacing: 12,
              children: [
                for (final role in TypeRole.values) _RoleSample(role, size),
              ],
            ),
          ),
        const DemoSection(
          title: 'Weights',
          description:
              'Weight comes from the font variation (wght + opsz), so a label '
              'turning semibold keeps nearly the same width.',
          child: _Weights(),
        ),
        const DemoSection(
          title: 'Tabular figures',
          description:
              'Numbers that line up use tabular figures; prose keeps '
              'proportional ones.',
          child: _Figures(),
        ),
      ],
    );
  }
}

class _RoleSample extends StatelessWidget {
  const _RoleSample(this.role, this.size);

  final TypeRole role;
  final CoilSize size;

  @override
  Widget build(BuildContext context) {
    final step = role.step(CoilTheme.tierOf(context), size);
    final colors = CoilTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${role.label} · ${_n(step.fontSize)}/${_n(step.lineHeight)} · '
          '${role.weight.name}',
          style: TypeRole.micro.styleOf(context, color: colors.mutedForeground),
        ),
        const SizedBox(height: 2),
        Text(
          'Restraint in motion and color',
          style: role.styleOf(context, size: size),
        ),
      ],
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _Weights extends StatelessWidget {
  const _Weights();

  @override
  Widget build(BuildContext context) => DemoColumn(
    spacing: 8,
    children: [
      for (final weight in CoilWeight.values)
        Text(
          '${weight.name} · wght ${weight.wght.round()} · opsz '
          '${weight.opsz.round()}',
          style: TypeRole.title.styleOf(context, weight: weight),
        ),
    ],
  );
}

class _Figures extends StatelessWidget {
  const _Figures();

  @override
  Widget build(BuildContext context) {
    final style = TypeRole.body.styleOf(context);
    final tabular = style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
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
            child: Text('1,111.11\n9,999.99\n4,041.70', style: tabular),
          ),
        ),
      ],
    );
  }
}
