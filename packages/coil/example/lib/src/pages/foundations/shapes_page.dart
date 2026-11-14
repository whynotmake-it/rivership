import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const shapesEntry = CatalogEntry(
  slug: 'shapes',
  title: 'Shapes',
  group: CatalogGroup.foundations,
  summary: 'Superellipses only: rounded, pill and sharp, per tier.',
  page: ShapesPage.new,
);

/// coil's shape presets, by name.
const _shapes = [
  ('rounded', CoilShape.rounded),
  ('pill', CoilShape.pill),
  ('sharp', CoilShape.sharp),
];

class ShapesPage extends StatefulWidget {
  const ShapesPage({super.key});

  @override
  State<ShapesPage> createState() => _ShapesPageState();
}

class _ShapesPageState extends State<ShapesPage> {
  var _shape = CoilShape.rounded;
  var _framework = 'flutter';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Shapes',
    summary:
        'Every rounded corner is a superellipse. Touch corners are larger so '
        'taller controls keep their proportions.',
    children: [
      DemoSection(
        title: 'Radii',
        description: 'Item, container and focus ring for each shape family.',
        child: DemoColumn(
          children: [
            for (final (name, shape) in _shapes) _ShapeRow(name, shape),
          ],
        ),
      ),
      DemoSection(
        title: 'Try a shape family',
        description:
            'CoilTheme.override swaps the family for a subtree; every control '
            'in it follows.',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Shape'),
              orientation: CoilFieldOrientation.responsive,
              child: CoilSelect<CoilShape>(
                value: _shape,
                onChanged: (value) => setState(() => _shape = value),
                options: [
                  for (final (name, shape) in _shapes)
                    CoilOption(
                      value: shape,
                      label: Text(name),
                      searchText: name,
                    ),
                ],
              ),
            ),
            CoilTheme.override(
              transform: (theme) => theme.copyWith(shape: _shape),
              child: DemoColumn(
                children: [
                  DemoWrap(
                    children: [
                      CoilButton(onPressed: () {}, child: const Text('Save')),
                      CoilButton(
                        variant: CoilButtonVariant.tertiary,
                        onPressed: () {},
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const CoilInput(
                    placeholder: Text('ada@example.com'),
                    semanticLabel: 'Email',
                  ),
                  CoilTabs<String>(
                    value: _framework,
                    onChanged: (value) => setState(() => _framework = value),
                    tabs: const [
                      CoilTab(value: 'flutter', label: Text('Flutter')),
                      CoilTab(value: 'web', label: Text('Web')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ShapeRow extends StatelessWidget {
  const _ShapeRow(this.name, this.shape);

  final String name;
  final CoilShape shape;

  @override
  Widget build(BuildContext context) {
    final tier = CoilTheme.tierOf(context);
    final radii = shape.radii(tier);
    final metrics = CoilTheme.metricsOf(context);
    final colors = CoilTheme.of(context).colors;
    // A pill's item radius is half the control height.
    final item = radii.item.clamp(0, metrics.controlHeight / 2).toDouble();
    return Labeled(
      '$name · item ${radii.item.round()} · container '
      '${radii.container.round()} · ring ${radii.focusRing.round()}',
      child: Row(
        children: [
          _Block(
            width: 96,
            height: metrics.controlHeight,
            radius: item,
            color: colors.active,
          ),
          const SizedBox(width: 16),
          // An item ringed 2 px outside: radius + 2, so it stays concentric.
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(item + 2),
                side: BorderSide(color: colors.focusRing),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _Block(
                width: 72,
                height: metrics.controlHeight,
                radius: item,
                color: colors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _Block(
            width: 72,
            height: 56,
            radius: radii.container,
            color: colors.surface(3),
            border: colors.border,
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    this.border,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final border = this.border;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
        ),
      ),
    );
  }
}
