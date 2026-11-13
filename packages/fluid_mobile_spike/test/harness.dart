import 'package:fluid_mobile_spike/fluid_mobile_spike.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const fruits = [
  FluidOption(value: 'apple', label: 'Apple'),
  FluidOption(value: 'banana', label: 'Banana'),
  FluidOption(value: 'blueberry', label: 'Blueberry'),
  FluidOption(value: 'cherry', label: 'Cherry'),
  FluidOption(value: 'grapes', label: 'Grapes', enabled: false),
  FluidOption(value: 'mango', label: 'Mango'),
  FluidOption(value: 'orange', label: 'Orange'),
];

/// A desktop window (pointer) or a phone (touch, with a notch and a home
/// indicator), at 2x.
enum TestScreen {
  desktop(Size(420, 440), FluidInputMode.pointer, EdgeInsets.zero),
  phone(
    Size(390, 844),
    FluidInputMode.touch,
    EdgeInsets.only(top: 47, bottom: 34),
  );

  const TestScreen(this.size, this.inputMode, this.padding);

  final Size size;
  final FluidInputMode inputMode;
  final EdgeInsets padding;
}

void useScreen(WidgetTester tester, TestScreen screen) {
  const dpr = 2.0;
  tester.view
    ..devicePixelRatio = dpr
    ..physicalSize = screen.size * dpr
    ..padding = FakeViewPadding(
      top: screen.padding.top * dpr,
      bottom: screen.padding.bottom * dpr,
    );
  addTearDown(tester.view.reset);
}

/// An app whose first page is [home], with the fluid scope and theme above
/// the navigator so routes inherit them.
Widget testApp({
  required Widget home,
  FluidColors colors = FluidColors.light,
  FluidInputMode? inputMode,
  FluidPresentation? presentation,
}) {
  return WidgetsApp(
    color: colors.focusRing,
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => FluidAdaptiveScope(
      inputMode: inputMode,
      presentation: presentation,
      child: FluidTheme(
        colors: colors,
        child: DefaultTextStyle(
          style: FluidMetrics.pointer.body.style(color: colors.foreground),
          child: ColoredBox(color: colors.background, child: navigator),
        ),
      ),
    ),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (context, _, _) =>
          ColoredBox(color: colors.background, child: home),
    ),
  );
}

/// A labelled select whose value lives in the harness.
class SelectDemo extends StatefulWidget {
  const SelectDemo({
    this.initial = 'banana',
    this.onChanged,
    this.presentation,
    this.autofocus = false,
    super.key,
  });

  final String? initial;
  final ValueChanged<String>? onChanged;
  final FluidPresentation? presentation;
  final bool autofocus;

  @override
  State<SelectDemo> createState() => SelectDemoState();
}

class SelectDemoState extends State<SelectDemo> {
  late String? value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    final metrics = FluidAdaptiveScope.metricsOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fruit',
              style: metrics.body.style(
                weight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 220,
              child: FluidSelect<String>(
                key: const ValueKey('select'),
                autofocus: widget.autofocus,
                options: fruits,
                value: value,
                presentation: widget.presentation,
                sheetTitle: const Text('Fruit'),
                onChanged: (next) {
                  setState(() => value = next);
                  widget.onChanged?.call(next);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
