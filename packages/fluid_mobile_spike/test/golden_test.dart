@Tags(['golden'])
library;

import 'package:fluid_mobile_spike/fluid_mobile_spike.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

// Goldens render real Inter (see flutter_test_config.dart), so they are
// platform-specific: regenerate with `flutter test --update-goldens` on the
// machine that checks them.

final _select = find.byKey(const ValueKey('select'));
final _app = find.byType(WidgetsApp);

/// Clicks the trigger with a mouse that stays connected afterwards.
Future<TestGesture> _click(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(_select));
  await mouse.down(tester.getCenter(_select));
  await mouse.up();
  await tester.pumpAndSettle();
  return mouse;
}

void main() {
  for (final colors in [FluidColors.light, FluidColors.dark]) {
    final theme = colors.brightness.name;

    group(theme, () {
      Future<void> pumpDesktop(WidgetTester tester, {bool autofocus = false}) {
        useScreen(tester, TestScreen.desktop);
        return tester.pumpWidget(
          testApp(
            home: SelectDemo(autofocus: autofocus),
            colors: colors,
            inputMode: FluidInputMode.pointer,
          ),
        );
      }

      testWidgets('desktop popover at rest', (tester) async {
        await pumpDesktop(tester);
        final mouse = await _click(tester);
        // Move the mouse off the list so nothing is hovered.
        await mouse.moveTo(const Offset(400, 20));
        await tester.pumpAndSettle();
        await expectLater(
          _app,
          matchesGoldenFile('goldens/desktop_popover_rest_$theme.png'),
        );
      });

      testWidgets('desktop popover, row hovered', (tester) async {
        await pumpDesktop(tester);
        final mouse = await _click(tester);
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.text('Cherry')));
        await tester.pumpAndSettle();
        await expectLater(
          _app,
          matchesGoldenFile('goldens/desktop_popover_hovered_$theme.png'),
        );
      });

      testWidgets('desktop popover, row reached with the keyboard', (
        tester,
      ) async {
        await pumpDesktop(tester, autofocus: true);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await expectLater(
          _app,
          matchesGoldenFile('goldens/desktop_popover_keyboard_$theme.png'),
        );
      });

      testWidgets('mobile sheet open', (tester) async {
        useScreen(tester, TestScreen.phone);
        await tester.pumpWidget(
          testApp(
            home: const SelectDemo(),
            colors: colors,
            inputMode: FluidInputMode.touch,
          ),
        );
        await tester.tap(_select);
        await tester.pumpAndSettle();
        await expectLater(
          _app,
          matchesGoldenFile('goldens/mobile_sheet_open_$theme.png'),
        );
      });

      testWidgets('controls at pointer vs touch size', (tester) async {
        useScreen(tester, TestScreen.desktop);
        tester.view.physicalSize = const Size(560, 600) * 2;
        await tester.pumpWidget(
          testApp(
            home: const _Comparison(),
            colors: colors,
            inputMode: FluidInputMode.pointer,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          _app,
          matchesGoldenFile('goldens/size_comparison_$theme.png'),
        );
      });
    });
  }
}

/// The same controls at the pointer step and the touch step, side by side.
class _Comparison extends StatelessWidget {
  const _Comparison();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Column(
              title: 'Pointer · 36px · body 13/20',
              metrics: FluidMetrics.pointer,
              iconButton: 28,
            ),
          ),
          SizedBox(width: 32),
          Expanded(
            child: _Column(
              title: 'Touch · 44px · body 15/20',
              metrics: FluidMetrics.touch,
              iconButton: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.metrics,
    required this.iconButton,
  });

  final String title;
  final FluidMetrics metrics;

  /// Visual size of a compact icon button at this step.
  final double iconButton;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    final caption = FluidMetrics.pointer.caption.style(
      color: colors.mutedForeground,
    );
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: caption),
    );
    final radius = BorderRadius.circular(metrics.controlRadius);

    Widget button(String text, {required bool primary}) => Container(
      height: metrics.controlHeight,
      padding: EdgeInsets.symmetric(horizontal: metrics.controlPaddingX),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? colors.foreground : colors.tint,
        borderRadius: radius,
      ),
      child: Text(
        text,
        style: metrics.body.style(
          weight: FontWeight.w500,
          color: primary ? colors.background : colors.foreground,
        ),
      ),
    );

    final hit = metrics.minHitTarget > iconButton
        ? metrics.minHitTarget
        : iconButton;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FluidMetrics.pointer.body.style(
            weight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        label('Buttons'),
        Row(
          children: [
            button('Continue', primary: true),
            SizedBox(width: metrics.gap),
            button('Cancel', primary: false),
          ],
        ),
        label('Select trigger'),
        FluidTriggerBox(metrics: metrics, label: const Text('Banana')),
        label('Input'),
        Container(
          height: metrics.controlHeight,
          padding: EdgeInsets.symmetric(horizontal: metrics.controlPaddingX),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: radius,
          ),
          child: Text(
            'hello@fluid.dev',
            style: metrics.body
                .style(color: colors.foreground)
                .copyWith(fontSize: metrics.fieldFontSize),
          ),
        ),
        label('Menu rows (checked, hovered, rest)'),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface(3),
            borderRadius: BorderRadius.circular(metrics.containerRadius),
            boxShadow: colors.shadow(3),
            border: colors.insetRing(3),
          ),
          child: Padding(
            padding: EdgeInsets.all(metrics.popupInset),
            child: Column(
              children: [
                for (final (i, text) in ['Banana', 'Cherry', 'Mango'].indexed)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: switch (i) {
                        0 => colors.active,
                        1 => colors.hover,
                        _ => null,
                      },
                      borderRadius: BorderRadius.circular(metrics.itemRadius),
                    ),
                    child: FluidOptionRow(
                      label: Text(text),
                      metrics: metrics,
                      highlighted: i < 2,
                      checked: i == 0,
                    ),
                  ),
              ],
            ),
          ),
        ),
        label('Icon button: visual ${iconButton.round()}, hit ${hit.round()}'),
        SizedBox.square(
          dimension: hit,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: colors.focusRing.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Container(
                width: iconButton,
                height: iconButton,
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(metrics.controlRadius),
                ),
                child: CustomPaint(painter: _PlusPainter(colors.foreground)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlusPainter extends CustomPainter {
  _PlusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.22;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(c - Offset(r, 0), c + Offset(r, 0), paint)
      ..drawLine(c - Offset(0, r), c + Offset(0, r), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}
