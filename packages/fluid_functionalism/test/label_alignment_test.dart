// Cases are built with a positional "ink" flag for brevity.
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/test_icons.dart';

/// Measures where a cap-only label ("HEH": flat cap tops, flat baseline,
/// no overshoot) actually inks inside each control, at every tier and text
/// scale, and asserts the cap band is vertically centered (CSS
/// `text-box: trim-both cap alphabetic`).
///
/// Each case is rendered twice, label visible and label at opacity 0, and
/// the two rasters are diffed, so the measured ink is exactly the label's,
/// whatever the fill behind it.
void main() {
  const pixelRatio = 4.0;
  const tolerance = 0.5;
  final results = <String>[];

  tearDownAll(() {
    // ignore: avoid_print
    print(
      'label centering (top gap / bottom gap, logical px):\n'
      '${results.join('\n')}',
    );
  });

  final tiers = <String, (FluidTier, FluidDensity)>{
    'desktop': (FluidTier.desktop, FluidDensity.regular),
    'desktop-compact': (FluidTier.desktop, FluidDensity.compact),
    'touch': (FluidTier.touch, FluidDensity.regular),
    'touch-compact': (FluidTier.touch, FluidDensity.compact),
  };
  const scales = [1.0, 1.5, 2.0];

  // Each case builds the control with the label shown or hidden.
  final cases = <String, Widget Function(bool ink)>{
    for (final v in FluidButtonVariant.values) ...{
      'button/${v.name}': (ink) => FluidButton(
        onPressed: () {},
        variant: v,
        child: _Ink(ink, const Text('HEH')),
      ),
      'button/${v.name}+icons': (ink) => FluidButton(
        onPressed: () {},
        variant: v,
        leading: const TestIcon(TestGlyph.plus),
        trailing: const TestIcon(TestGlyph.arrowRight),
        child: _Ink(ink, const Text('HEH')),
      ),
    },
    'tabs/text': (ink) => FluidTabs(
      tabs: [
        FluidTab(label: _Ink(ink, const Text('HEH'))),
        FluidTab(label: _Ink(ink, const Text('HEH'))),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
    ),
    'tabs/icons': (ink) => FluidTabs(
      tabs: [
        FluidTab(
          icon: const TestIcon(TestGlyph.home),
          label: _Ink(ink, const Text('HEH')),
        ),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
    ),
    'input/text': (ink) => SizedBox(
      width: 200,
      child: FluidInput(
        controller: TextEditingController(text: ink ? 'HEH' : ''),
      ),
    ),
    'input/placeholder': (ink) => SizedBox(
      width: 200,
      child: FluidInput(placeholder: _Ink(ink, const Text('HEH'))),
    ),
    'switch/label': (ink) => FluidSwitch(
      value: true,
      onChanged: (_) {},
      label: _Ink(ink, const Text('HEH')),
    ),
  };

  for (final MapEntry(key: name, value: build) in cases.entries) {
    for (final MapEntry(key: tierName, value: (tier, density))
        in tiers.entries) {
      for (final scale in scales) {
        final label = '$name @ $tierName x$scale';
        testWidgets(label, (tester) async {
          final boundary = GlobalKey();
          // Overlay entries are built once, so the content changes through
          // a notifier rather than by pumping a new tree.
          final content = ValueNotifier<Widget>(build(true));
          addTearDown(content.dispose);
          await tester.pumpWidget(
            _Harness(
              tier: tier,
              density: density,
              scale: scale,
              boundary: boundary,
              content: content,
            ),
          );
          Future<Uint8List> render(bool ink) async {
            content.value = build(ink);
            for (var i = 0; i < 3; i++) {
              await tester.pump(const Duration(milliseconds: 400));
            }
            final box = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(boundary),
            );
            final bytes = await tester.runAsync(() async {
              final image = await box.toImage(pixelRatio: pixelRatio);
              final data = await image.toByteData();
              image.dispose();
              return data!.buffer.asUint8List();
            });
            return bytes!;
          }

          final withInk = await render(true);
          final without = await render(false);
          final box = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
              .size;
          final width = (box.width * pixelRatio).round();
          final height = (box.height * pixelRatio).round();

          int? top;
          int? bottom;
          for (var y = 0; y < height; y++) {
            for (var x = 0; x < width; x++) {
              final i = (y * width + x) * 4;
              var diff = 0;
              for (var c = 0; c < 4; c++) {
                diff += (withInk[i + c] - without[i + c]).abs();
              }
              // Half-covered antialiased edge pixels count as ink.
              if (diff > 160) {
                top ??= y;
                bottom = y;
                break;
              }
            }
          }
          expect(top, isNotNull, reason: 'no label ink found');
          final topGap = top! / pixelRatio;
          final bottomGap = (height - 1 - bottom!) / pixelRatio;
          final delta = topGap - bottomGap;
          results.add(
            '${label.padRight(44)} ${topGap.toStringAsFixed(2).padLeft(6)} / '
            '${bottomGap.toStringAsFixed(2).padLeft(6)}  '
            'Δ ${delta.toStringAsFixed(2)}',
          );
          expect(
            delta.abs(),
            lessThanOrEqualTo(tolerance),
            reason:
                'cap band off center by ${delta.toStringAsFixed(2)} px '
                '(top $topGap, bottom $bottomGap)',
          );
        });
      }
    }
  }
}

/// Shows or hides a label without changing layout.
class _Ink extends StatelessWidget {
  const _Ink(this.visible, this.child);

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: visible ? 1 : 0, child: child);
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.tier,
    required this.density,
    required this.scale,
    required this.boundary,
    required this.content,
  });

  final FluidTier tier;
  final FluidDensity density;
  final double scale;
  final GlobalKey boundary;
  final ValueListenable<Widget> content;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (_) => FluidTheme(
              data: FluidThemeData.light.copyWith(tier: tier),
              child: FluidSizeScope(
                density: density,
                child: Center(
                  child: RepaintBoundary(
                    key: boundary,
                    child: ValueListenableBuilder(
                      valueListenable: content,
                      builder: (context, child, _) => child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
