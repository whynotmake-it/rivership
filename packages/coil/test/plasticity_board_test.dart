// Visual harness for CoilPlasticity: comparison boards and recordings for
// picking a direction. Skipped unless PLASTICITY_OUT names an output
// directory:
//
//   PLASTICITY_OUT=/tmp/plasticity flutter test test/plasticity_board_test.dart
import 'dart:io';

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

import 'src/golden_sheet.dart';

final String? _out = Platform.environment['PLASTICITY_OUT'];

/// The first round's A: opencode's recipe on every role at full strength,
/// before `CoilPlasticity.subtle` was refined.
const _subtleV1 = CoilPlasticity(
  edge: 1,
  edgeWidth: 0.5,
  highlight: 1,
  shade: 0.5,
  sheen: 1,
  lift: 1,
  recess: 0.6,
  containers: 1,
);

/// The directions shown to the owner in the first round.
final _variants = <String, (String, CoilPlasticity)>{
  'flat': ('Flat (today, default)', CoilPlasticity.flat),
  'a_subtle': ('A · subtle (opencode-faithful)', _subtleV1),
  'b_soft': ('B · soft-lit', CoilPlasticity.soft),
  'c_tactile': ('C · tactile', CoilPlasticity.tactile),
};

/// Intensity steps of the recommended direction.
final _steps = <String, (String, CoilPlasticity)>{
  'a_subtle_x0.5': ('A · subtle × 0.5', _subtleV1.scale(0.5)),
  'a_subtle_x1.0': ('A · subtle × 1', _subtleV1),
  'a_subtle_x1.6': ('A · subtle × 1.6', _subtleV1.scale(1.6)),
  'a_subtle_x2.2': ('A · subtle × 2.2', _subtleV1.scale(2.2)),
};

/// The second round: flat, the first A and the refined A
/// (`CoilPlasticity.subtle`).
final _refined = <String, (String, CoilPlasticity)>{
  'flat': ('Flat (today, default)', CoilPlasticity.flat),
  'a_subtle': ('A · subtle (round 1)', _subtleV1),
  'a_refined': ('A-refined (CoilPlasticity.subtle)', CoilPlasticity.subtle),
};

/// Intensity steps of the refined A.
final _refinedSteps = <String, (String, CoilPlasticity)>{
  'x0.5': ('A-refined × 0.5', CoilPlasticity.subtle.scale(0.5)),
  'x0.75': ('A-refined × 0.75', CoilPlasticity.subtle.scale(0.75)),
  'x1': ('A-refined × 1', CoilPlasticity.subtle),
};

const _boardWidth = 540.0;

SnaptestSettings _still() => SnaptestSettings(
  blockText: false,
  renderShadows: true,
  pathPrefix: _out!,
);

void main() {
  final skip = _out == null;

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    required Size size,
    double dpr = 2,
  }) async {
    tester.view
      ..devicePixelRatio = dpr
      ..physicalSize = size * dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: dpr),
          child: Overlay(
            initialEntries: [OverlayEntry(builder: (_) => child)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await snap(name: name, settings: _still());
  }

  group('plasticity boards', skip: skip, () {
    for (final MapEntry(key: id, value: (title, p)) in {
      ..._variants,
      ..._steps,
    }.entries) {
      testWidgets(id, (tester) async {
        await shoot(
          tester,
          'board_$id',
          _Pair(title: title, plasticity: p),
          size: const Size(_boardWidth * 2 + 3 * 24, 900),
        );
      });
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('side by side ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'side_by_side_${brightness.name}',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (title, p) in _variants.values)
                _Board(title: title, plasticity: p, brightness: brightness),
            ],
          ),
          size: const Size(_boardWidth * 4, 900),
        );
      });
      testWidgets('intensity steps ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'intensity_steps_${brightness.name}',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (title, p) in _steps.values)
                _Board(title: title, plasticity: p, brightness: brightness),
            ],
          ),
          size: const Size(_boardWidth * 4, 900),
        );
      });
      testWidgets('detail ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'detail_4x_${brightness.name}',
          Column(
            children: [
              for (final (title, p) in _variants.values)
                _Detail(title: title, plasticity: p, brightness: brightness),
            ],
          ),
          size: const Size(620, 4 * 132),
          dpr: 4,
        );
      });
    }
  });

  group('plasticity refined', skip: skip, () {
    testWidgets('board', (tester) async {
      final (title, p) = _refined['a_refined']!;
      await shoot(
        tester,
        'refined_board_a_refined',
        _Pair(title: title, plasticity: p),
        size: const Size(_boardWidth * 2 + 3 * 24, 900),
      );
    });
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('side by side ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'refined_side_by_side_${brightness.name}',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (title, p) in _refined.values)
                _Board(title: title, plasticity: p, brightness: brightness),
            ],
          ),
          size: const Size(_boardWidth * 3, 900),
        );
      });
      testWidgets('intensity ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'refined_intensity_${brightness.name}',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (title, p) in _refinedSteps.values)
                _Board(title: title, plasticity: p, brightness: brightness),
            ],
          ),
          size: const Size(_boardWidth * 3, 900),
        );
      });
      testWidgets('detail ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'refined_detail_4x_${brightness.name}',
          Column(
            children: [
              for (final id in ['a_subtle', 'a_refined'])
                _Detail(
                  title: _refined[id]!.$1,
                  plasticity: _refined[id]!.$2,
                  brightness: brightness,
                ),
            ],
          ),
          size: const Size(620, 2 * 132),
          dpr: 4,
        );
      });
    }
  });

  // Round 3: controls on a card or popover are flat (CoilPlasticityScope).
  group('plasticity refined2', skip: skip, () {
    testWidgets('board', (tester) async {
      final (title, p) = _refined['a_refined']!;
      await shoot(
        tester,
        'refined2_board_a_refined',
        _Pair(title: title, plasticity: p),
        size: const Size(_boardWidth * 2 + 3 * 24, 900),
      );
    });
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('side by side ${brightness.name}', (tester) async {
        await shoot(
          tester,
          'refined2_side_by_side_${brightness.name}',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (title, p) in _refined.values)
                _Board(title: title, plasticity: p, brightness: brightness),
            ],
          ),
          size: const Size(_boardWidth * 3, 900),
        );
      });
    }
  });

  group('plasticity recordings', skip: skip, () {
    for (final id in ['a_subtle', 'c_tactile', 'b_soft', 'a_refined']) {
      testWidgets('interaction $id', (tester) async {
        final (title, p) = {..._variants, ..._refined}[id]!;
        const size = Size(2 * 330, 230);
        tester.view
          ..devicePixelRatio = 2
          ..physicalSize = size * 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: size, devicePixelRatio: 2),
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (_) => _Playground(title: title, plasticity: p),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final recording = await snap.recordVideo(
          name: id == 'a_refined'
              ? 'refined_interaction_a_refined'
              : 'interaction_$id',
          settings: SnapVideoSettings(
            pathPrefix: _out!,
            timing: VideoTiming.smooth,
            renderShadows: true,
            showPointers: true,
            finalHold: const Duration(milliseconds: 400),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(4, 4));
        addTearDown(mouse.removePointer);

        Future<void> glide(Offset to, {int ms = 260}) async {
          await mouse.moveTo(to);
          await tester.pump(Duration(milliseconds: ms));
        }

        Future<void> click(Offset at) async {
          await glide(at, ms: 500);
          await mouse.down(at);
          await tester.pump(const Duration(milliseconds: 450));
          await mouse.up();
          await tester.pump(const Duration(milliseconds: 500));
        }

        for (final brightness in [Brightness.light, Brightness.dark]) {
          final key = ValueKey(brightness);
          Offset center(String what) => tester.getCenter(
            find.descendant(
              of: find.byKey(key),
              matching: find.byKey(ValueKey(what)),
            ),
          );
          await click(center('secondary'));
          await click(center('primary'));
          await click(center('switch'));
          // Drag the slider knob along its track.
          final track = tester.getRect(
            find.descendant(
              of: find.byKey(key),
              matching: find.byKey(const ValueKey('slider')),
            ),
          );
          final knob = Offset(track.left + track.width * 0.62, track.center.dy);
          await glide(knob, ms: 400);
          await mouse.down(knob);
          await tester.pump(const Duration(milliseconds: 200));
          for (var i = 1; i <= 24; i++) {
            await mouse.moveTo(knob + Offset(-i * 3.0, 0));
            await tester.pump(const Duration(milliseconds: 25));
          }
          for (var i = 1; i <= 30; i++) {
            await mouse.moveTo(knob + Offset(-72 + i * 4.0, 0));
            await tester.pump(const Duration(milliseconds: 25));
          }
          await mouse.up();
          await tester.pump(const Duration(milliseconds: 300));
          await glide(Offset(center('switch').dx, 210), ms: 400);
        }
        await recording.stop();
      });
    }
  });
}

CoilThemeData _theme(Brightness brightness, CoilPlasticity p) =>
    (brightness == Brightness.light ? goldenLight : goldenDark).copyWith(
      plasticity: p,
      tier: CoilTier.pointer,
    );

/// A light and a dark board for one plasticity.
class _Pair extends StatelessWidget {
  const _Pair({required this.title, required this.plasticity});

  final String title;
  final CoilPlasticity plasticity;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF8A8A8A),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          for (final b in [Brightness.light, Brightness.dark])
            ClipRSuperellipse(
              borderRadius: BorderRadius.circular(16),
              child: _Board(
                title: title,
                plasticity: plasticity,
                brightness: b,
              ),
            ),
        ],
      ),
    ),
  );
}

/// A realistic panel of controls under one plasticity and brightness.
class _Board extends StatelessWidget {
  const _Board({
    required this.title,
    required this.plasticity,
    required this.brightness,
  });

  final String title;
  final CoilPlasticity plasticity;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final theme = _theme(brightness, plasticity);
    return CoilTheme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = CoilTheme.of(context).colors;
          final text = CoilTheme.textOf(context);
          Widget section(String label, Widget child) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(label, style: text.muted.caption),
              child,
            ],
          );
          WidgetStatesController forced(Set<WidgetState> s) =>
              WidgetStatesController(s);
          Widget button(
            CoilButtonVariant variant,
            String label, {
            Set<WidgetState> states = const {},
            bool enabled = true,
          }) => CoilButton(
            variant: variant,
            statesController: forced(states),
            onPressed: enabled ? () {} : null,
            child: Text(label),
          );
          return SizedBox(
            width: _boardWidth,
            child: ColoredBox(
              color: colors.background,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 18,
                  children: [
                    Text(
                      '$title — ${brightness.name}',
                      style: text.subtitle,
                    ),
                    section(
                      'Buttons: primary, secondary, tertiary, ghost '
                      '(hovered), destructive',
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          button(.primary, 'Deploy'),
                          button(.secondary, 'Share'),
                          button(.tertiary, 'Export'),
                          button(
                            .ghost,
                            'Ghost',
                            states: {WidgetState.hovered},
                          ),
                          button(.destructive, 'Delete'),
                        ],
                      ),
                    ),
                    section(
                      'States: rest · hover · pressed · disabled',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          for (final v in [
                            CoilButtonVariant.secondary,
                            CoilButtonVariant.primary,
                          ])
                            Row(
                              spacing: 8,
                              children: [
                                button(v, 'Rest'),
                                button(
                                  v,
                                  'Hover',
                                  states: {WidgetState.hovered},
                                ),
                                button(
                                  v,
                                  'Pressed',
                                  states: {
                                    WidgetState.hovered,
                                    WidgetState.pressed,
                                  },
                                ),
                                button(v, 'Disabled', enabled: false),
                              ],
                            ),
                        ],
                      ),
                    ),
                    section(
                      'Switch, checkbox, radio',
                      Row(
                        spacing: 20,
                        children: [
                          CoilSwitch(value: false, onChanged: (_) {}),
                          CoilSwitch(value: true, onChanged: (_) {}),
                          CoilCheckbox(value: false, onChanged: (_) {}),
                          CoilCheckbox(value: true, onChanged: (_) {}),
                          SizedBox(
                            width: 200,
                            child: CoilRadioGroup<int>(
                              value: 0,
                              onChanged: (_) {},
                              options: const [
                                CoilOption(
                                  value: 0,
                                  label: Text('Monthly'),
                                  searchText: 'Monthly',
                                ),
                                CoilOption(
                                  value: 1,
                                  label: Text('Yearly'),
                                  searchText: 'Yearly',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    section(
                      'Sliders: pill and scrubber',
                      Column(
                        spacing: 8,
                        children: [
                          CoilSlider(
                            value: 0.4,
                            onChanged: (_) {},
                            variant: CoilSliderVariant.pill,
                            label: const Text('Volume'),
                          ),
                          CoilSlider(
                            value: 0.62,
                            onChanged: (_) {},
                            label: const Text('Opacity'),
                          ),
                        ],
                      ),
                    ),
                    section(
                      'Segmented toggle and tabs',
                      Row(
                        spacing: 16,
                        children: [
                          CoilToggleGroup<int>(
                            values: const {0},
                            onChanged: (_) {},
                            options: const [
                              CoilOption(
                                value: 0,
                                label: Text('Day'),
                                searchText: 'Day',
                              ),
                              CoilOption(
                                value: 1,
                                label: Text('Week'),
                                searchText: 'Week',
                              ),
                              CoilOption(
                                value: 2,
                                label: Text('Month'),
                                searchText: 'Month',
                              ),
                            ],
                          ),
                          CoilTabs<int>(
                            value: 1,
                            onChanged: (_) {},
                            tabs: const [
                              CoilTab(value: 0, label: Text('Code')),
                              CoilTab(value: 1, label: Text('Review')),
                              CoilTab(value: 2, label: Text('Logs')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    section(
                      'Input and select',
                      Row(
                        spacing: 8,
                        children: [
                          const Expanded(
                            child: CoilInput(
                              placeholder: Text('Search files…'),
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: CoilSelect<String>(
                              value: 'sonnet',
                              onChanged: (_) {},
                              placeholder: const Text('Model'),
                              options: const [
                                CoilOption(
                                  value: 'sonnet',
                                  label: Text('Sonnet'),
                                  searchText: 'Sonnet',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    section(
                      'Card and popover',
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 16,
                        children: [
                          Expanded(
                            child: CoilCard(
                              title: const Text('Preview ready'),
                              description: const Text('Built 2 minutes ago'),
                              actions: [
                                CoilButton(
                                  onPressed: () {},
                                  variant: .secondary,
                                  size: .compact,
                                  child: const Text('Open'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: CoilPopoverSurface(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final (i, item) in [
                                      'Rename',
                                      'Duplicate',
                                      'Move to…',
                                    ].indexed)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: i == 1
                                              ? colors.hover
                                              : colors.hover.withValues(
                                                  alpha: 0,
                                                ),
                                          shape: RoundedSuperellipseBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(item),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A close-up row: buttons, switch, slider knob and an input, at 4x.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.title,
    required this.plasticity,
    required this.brightness,
  });

  final String title;
  final CoilPlasticity plasticity;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) => CoilTheme(
    data: _theme(brightness, plasticity),
    child: Builder(
      builder: (context) {
        final colors = CoilTheme.of(context).colors;
        return Container(
          height: 132,
          color: colors.background,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(title, style: CoilTheme.textOf(context).muted.caption),
              Row(
                spacing: 10,
                children: [
                  CoilButton(onPressed: () {}, child: const Text('Deploy')),
                  CoilButton(
                    variant: .secondary,
                    onPressed: () {},
                    child: const Text('Share'),
                  ),
                  CoilSwitch(value: true, onChanged: (_) {}),
                  CoilSwitch(value: false, onChanged: (_) {}),
                  CoilCheckbox(value: true, onChanged: (_) {}),
                  const SizedBox(
                    width: 150,
                    child: CoilInput(placeholder: Text('Name')),
                  ),
                ],
              ),
              SizedBox(
                width: 300,
                child: CoilSlider(
                  value: 0.5,
                  onChanged: (_) {},
                  variant: CoilSliderVariant.pill,
                  label: const Text('Gain'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// What the recordings drive: a light and a dark strip of a secondary and
/// a primary button, a switch and a pill slider.
class _Playground extends StatefulWidget {
  const _Playground({required this.title, required this.plasticity});

  final String title;
  final CoilPlasticity plasticity;

  @override
  State<_Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<_Playground> {
  final _on = {Brightness.light: false, Brightness.dark: false};
  final _value = {Brightness.light: 0.62, Brightness.dark: 0.62};

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final b in [Brightness.light, Brightness.dark])
        CoilTheme(
          key: ValueKey(b),
          data: _theme(b, widget.plasticity),
          child: Builder(
            builder: (context) => Container(
              width: 330,
              height: 230,
              color: CoilTheme.of(context).colors.background,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Text(
                    '${widget.title} — ${b.name}',
                    style: CoilTheme.textOf(context).muted.caption,
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      CoilButton(
                        key: const ValueKey('secondary'),
                        variant: .secondary,
                        onPressed: () {},
                        child: const Text('Share'),
                      ),
                      CoilButton(
                        key: const ValueKey('primary'),
                        onPressed: () {},
                        child: const Text('Deploy'),
                      ),
                      CoilSwitch(
                        key: const ValueKey('switch'),
                        value: _on[b]!,
                        onChanged: (v) => setState(() => _on[b] = v),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 260,
                    child: CoilSlider(
                      key: const ValueKey('slider'),
                      value: _value[b]!,
                      onChanged: (v) => setState(() => _value[b] = v),
                      variant: CoilSliderVariant.pill,
                      label: const Text('Gain'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
