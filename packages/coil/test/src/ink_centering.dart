// Cases are built with a positional "ink" flag for brevity.
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a control with its label shown (`ink` true) or hidden.
typedef InkCase = Widget Function(bool ink);

/// Measures where a cap-only label ("HEH": flat cap tops, flat baseline,
/// no overshoot) actually inks inside each control in [cases], at every tier
/// and text scale, and asserts the cap band is vertically centered to within
/// the engine's baseline pixel rounding.
///
/// Each case is rendered twice, label visible and label at opacity 0 (wrap
/// the label in [InkLabel]), and the two rasters are diffed, so the measured
/// ink is exactly the label's, whatever the fill behind it.
void inkCenteringTests(Map<String, InkCase> cases) {
  const pixelRatio = 8.0;
  // The text engine rounds the first baseline to a whole logical pixel
  // (relative to the paragraph). That rounding is accepted, not
  // compensated: up to 0.5 px of offset, i.e. 1 px of top/bottom imbalance.
  const tolerance = 1.0;
  final results = <String>[];

  tearDownAll(() {
    // ignore: avoid_print
    print(
      'label centering (top gap / bottom gap, logical px):\n'
      '${results.join('\n')}',
    );
  });

  final tiers = <String, (CoilTier, CoilSize)>{
    'desktop': (CoilTier.pointer, CoilSize.regular),
    'desktop-compact': (CoilTier.pointer, CoilSize.compact),
    'touch': (CoilTier.touch, CoilSize.regular),
    'touch-compact': (CoilTier.touch, CoilSize.compact),
  };
  const scales = [1.0, 1.5, 2.0];

  for (final MapEntry(key: name, value: build) in cases.entries) {
    for (final MapEntry(key: tierName, value: (tier, size)) in tiers.entries) {
      for (final scale in scales) {
        final label = '$name @ $tierName x$scale';
        testWidgets(label, (tester) async {
          final boundary = GlobalKey();
          // Overlay entries are built once, so the content changes through
          // a notifier rather than by pumping a new tree.
          final content = ValueNotifier<Widget>(build(true));
          addTearDown(content.dispose);
          await tester.pumpWidget(
            _InkHarness(
              tier: tier,
              size: size,
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
class InkLabel extends StatelessWidget {
  /// Shows [child] when [visible], else keeps its layout invisibly.
  const InkLabel(this.visible, this.child, {super.key});

  /// Whether the label inks.

  final bool visible;

  /// The label.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: visible ? 1 : 0, child: child);
}

class _InkHarness extends StatelessWidget {
  const _InkHarness({
    required this.tier,
    required this.size,
    required this.scale,
    required this.boundary,
    required this.content,
  });

  final CoilTier tier;
  final CoilSize size;
  final double scale;
  final GlobalKey boundary;
  final ValueListenable<Widget> content;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (_) => CoilTheme(
              data: CoilThemeData.light.copyWith(tier: tier),
              child: CoilAdaptiveScope(
                size: size,
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
