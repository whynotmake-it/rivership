// Boards for the accent-button exploration, written to `.snaptest/`.
// Off by default; run with:
//   flutter test test/exploration --dart-define=EXPLORE=true
import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

import 'harness.dart';

const _enabled = bool.fromEnvironment('EXPLORE');

enum _State {
  rest('Rest', {}),
  hover('Hover', {WidgetState.hovered}),
  pressed('Pressed', {WidgetState.hovered, WidgetState.pressed}),
  focus('Focus', {WidgetState.focused}),
  disabled('Disabled', {}),
  loading('Loading', {});

  const _State(this.label, this.states);

  final String label;
  final Set<WidgetState> states;
}

/// One button in [state].
Widget _button(CoilButtonVariant variant, _State state, String label) =>
    CoilButton(
      variant: variant,
      onPressed: state == _State.disabled ? null : () {},
      loading: state == _State.loading,
      statesController: WidgetStatesController({...state.states}),
      child: Text(label),
    );

/// Variants × states for one theme.
Widget _stateGrid(CoilThemeData theme) {
  const rows = [
    (CoilButtonVariant.accent, 'Upgrade'),
    (CoilButtonVariant.primary, 'Upgrade'),
    (CoilButtonVariant.secondary, 'Cancel'),
    (CoilButtonVariant.ghost, 'Cancel'),
  ];
  return Builder(
    builder: (context) {
      final c = CoilTheme.of(context).colors;
      final caption = typography.pointerCompact.caption.copyWith(
        color: c.mutedForeground,
      );
      return Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox(),
              for (final s in _State.values)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Text(s.label, style: caption),
                ),
            ],
          ),
          for (final (variant, label) in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(variant.name, style: caption),
                ),
                for (final s in _State.values)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _button(variant, s, label),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

Future<void> _snapBoard(
  WidgetTester tester,
  String name,
  Widget board, {
  Size surface = const Size(5200, 5200),
}) async {
  final finder = await pumpBoard(tester, board, surface: surface);
  await snap(name: name, from: finder);
}

void main() {
  testWidgets('states', skip: !_enabled, (tester) async {
    for (final seed in seeds) {
      await _snapBoard(
        tester,
        'states_${seed.name}',
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in Brightness.values.reversed)
              Panel(
                theme: themeFor(seed, b),
                caption: '${seed.name} ${seed.hex} · ${b.name}',
                child: _stateGrid(themeFor(seed, b)),
              ),
          ],
        ),
      );
    }
  });

  testWidgets('shading', skip: !_enabled, (tester) async {
    for (final naive in [true, false]) {
      CoilRelief.debugNaiveTint = naive;
      addTearDown(() => CoilRelief.debugNaiveTint = false);
      for (final b in Brightness.values.reversed) {
        await _snapBoard(
          tester,
          'shading_${naive ? 'srgb' : 'oklch'}_${b.name}',
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final seed in seeds)
                Panel(
                  theme: themeFor(seed, b, plasticity: 1),
                  padding: 12,
                  child: SizedBox(
                    width: 132 * 2.5,
                    height: 44 * 2.5,
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: CoilButton(
                          variant: CoilButtonVariant.accent,
                          onPressed: () {},
                          trailing: const CatalogIcon(Glyph.arrowRight),
                          child: const Text('Upgrade'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }
  });

  testWidgets('labels', skip: !_enabled, (tester) async {
    // How the label color is picked, for brands where the rules disagree.
    const white = Color(0xFFFFFFFF);
    const ink = Color(0xFF171717);
    Widget cell(String caption, Color fill, Color label) => Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoilButton(
            variant: CoilButtonVariant.accent,
            onPressed: () {},
            style: CoilButtonStyle(
              fill: WidgetStatePropertyAll(fill),
              foreground: WidgetStatePropertyAll(label),
            ),
            trailing: const CatalogIcon(Glyph.arrowRight),
            child: const Text('Upgrade to Pro'),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final wcag = CoilColorMix.contrastRatio(label, fill);
              final apca = CoilColorMix.apcaContrast(label, fill).abs();
              return Text(
                '$caption\n'
                'WCAG ${wcag.toStringAsFixed(1)} · APCA Lc ${apca.round()}',
                style: typography.pointerCompact.caption.copyWith(
                  color: CoilTheme.of(context).colors.mutedForeground,
                ),
              );
            },
          ),
        ],
      ),
    );
    Color wcagTone(Color brand) =>
        CoilColorMix.ensureContrastByLightness(brand, white, 4.5);
    await _snapBoard(
      tester,
      'labels',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seed in seeds)
            Panel(
              theme: themeFor(seed, Brightness.light),
              padding: 16,
              caption: '${seed.name} ${seed.hex}',
              child: Builder(
                builder: (context) {
                  final c = CoilTheme.of(context).colors;
                  final wcagPick =
                      CoilColorMix.contrastRatio(ink, seed.color) >
                          CoilColorMix.contrastRatio(white, seed.color)
                      ? ink
                      : white;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cell('WCAG 2 pick, brand as given', seed.color, wcagPick),
                      cell(
                        'Darkened until white hits 4.5 : 1',
                        wcagTone(seed.color),
                        white,
                      ),
                      cell('Proposed: APCA pick', c.brandFill, c.onBrandFill),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  });

  testWidgets('tiers', skip: !_enabled, (tester) async {
    for (final seed in [seeds[0], seeds[4]]) {
      await _snapBoard(
        tester,
        'tiers_${seed.name}',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tier in CoilTier.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final b in Brightness.values.reversed)
                    SizedBox(
                      width: 520,
                      child: Panel(
                        theme: themeFor(seed, b, tier: tier),
                        caption: '${tier.name} · ${b.name}',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            for (final (v, label) in const [
                              (CoilButtonVariant.accent, 'Upgrade'),
                              (CoilButtonVariant.primary, 'Save'),
                              (CoilButtonVariant.secondary, 'Cancel'),
                              (CoilButtonVariant.ghost, 'Skip'),
                            ])
                              CoilButton(
                                variant: v,
                                onPressed: () {},
                                child: Text(label),
                              ),
                            CoilButton.icon(
                              variant: CoilButtonVariant.accent,
                              onPressed: () {},
                              icon: const CatalogIcon(Glyph.plus),
                              semanticLabel: 'Add',
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    }
  });

  testWidgets('controls', skip: !_enabled, (tester) async {
    Widget controls({required bool touched}) => Builder(
      builder: (context) {
        final c = CoilTheme.of(context).colors;
        final body = CoilTheme.of(context).typography.pointer.body;
        return SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoilTabs<int>(
                tabs: const [
                  CoilTab(value: 0, label: Text('General')),
                  CoilTab(value: 1, label: Text('Billing')),
                  CoilTab(value: 2, label: Text('Team')),
                ],
                value: 1,
                onChanged: (_) {},
              ),
              const SizedBox(height: 16),
              CoilSwitch(
                value: true,
                onChanged: (_) {},
                label: const Text('Email digests'),
              ),
              const SizedBox(height: 12),
              CoilCheckbox(value: true, onChanged: (_) {}),
              const SizedBox(height: 12),
              CoilRadioGroup<int>(
                options: const [
                  CoilOption(value: 0, label: Text('Daily')),
                  CoilOption(value: 1, label: Text('Weekly')),
                ],
                value: 1,
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              CoilSlider(
                value: 0.6,
                onChanged: (_) {},
                label: const Text('Volume'),
              ),
              const SizedBox(height: 12),
              CoilToggleGroup<int>(
                options: const [
                  CoilOption(value: 0, label: Text('Light')),
                  CoilOption(value: 1, label: Text('Dark')),
                  CoilOption(value: 2, label: Text('System')),
                ],
                values: const {2},
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  CoilBadge(color: CoilBadgeColor.brand, child: Text('New')),
                  SizedBox(width: 8),
                  CoilBadge(child: Text('Draft')),
                ],
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: body.copyWith(color: c.mutedForeground),
                  children: [
                    const TextSpan(text: 'Read the '),
                    TextSpan(
                      text: 'billing terms',
                      style: !touched
                          ? TextStyle(
                              color: c.foreground,
                              decoration: TextDecoration.underline,
                              decorationColor: c.border,
                            )
                          : TextStyle(color: c.brandInk),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    for (final b in Brightness.values.reversed) {
      await _snapBoard(
        tester,
        'controls_${b.name}',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final touched in [false, true])
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final seed in seeds)
                    Panel(
                      theme: touched
                          ? withBrandTouches(themeFor(seed, b))
                          : themeFor(seed, b),
                      caption:
                          '${seed.name} · ${touched ? 'touched' : 'current'}',
                      child: controls(touched: touched),
                    ),
                ],
              ),
          ],
        ),
      );
    }
  });
}
