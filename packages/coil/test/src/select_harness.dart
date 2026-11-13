import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const fruits = [
  CoilOption(value: 'apple', label: 'Apple'),
  CoilOption(value: 'banana', label: 'Banana'),
  CoilOption(value: 'blueberry', label: 'Blueberry'),
  CoilOption(value: 'cherry', label: 'Cherry'),
  CoilOption(value: 'grapes', label: 'Grapes', enabled: false),
  CoilOption(value: 'mango', label: 'Mango'),
  CoilOption(value: 'orange', label: 'Orange'),
];

/// More than `CoilAdaptivePopup.shortMenuMaxItems`, so a phone opens it in
/// a sheet.
const moreFruits = [
  ...fruits,
  CoilOption(value: 'peach', label: 'Peach'),
  CoilOption(value: 'pear', label: 'Pear'),
  CoilOption(value: 'plum', label: 'Plum'),
  CoilOption(value: 'raspberry', label: 'Raspberry'),
  CoilOption(value: 'strawberry', label: 'Strawberry'),
];

/// A desktop window (pointer) or a phone (touch, with a notch and a home
/// indicator), at 2x.
enum TestScreen {
  desktop(Size(420, 440), CoilTier.pointer, EdgeInsets.zero),
  phone(
    Size(390, 844),
    CoilTier.touch,
    EdgeInsets.only(top: 47, bottom: 34),
  );

  const TestScreen(this.size, this.tier, this.padding);

  final Size size;
  final CoilTier tier;
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

/// The repaint boundary around the whole test app, for pixel probes.
const appBoundary = ValueKey('app-boundary');

/// An app whose first page is [home], with the theme above the navigator
/// so routes inherit it.
Widget testApp({
  required Widget home,
  CoilColors colors = CoilColors.light,
  CoilMotion motion = const CoilMotion(),
  CoilTier? tier,
  CoilPresentation? presentation,
  CoilSelectStyle? selectStyle,
}) {
  var theme = CoilThemeData(colors: colors, motion: motion);
  if (selectStyle != null) theme = theme.withComponentStyle(selectStyle);
  return WidgetsApp(
    color: colors.focusRing,
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => RepaintBoundary(
      key: appBoundary,
      child: CoilAdaptiveScope(
        tier: tier,
        presentation: presentation,
        child: CoilTheme(
          data: theme,
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
    this.motion,
    this.options = fruits,
    this.multiple = false,
    this.initialValues = const {'banana', 'mango'},
    this.onValuesChanged,
    super.key,
  });

  /// The options. [fruits] (7) stays anchored on a phone, [moreFruits] (12)
  /// opens a sheet.
  final List<CoilOption<String>> options;
  final bool multiple;
  final Set<String> initialValues;
  final ValueChanged<Set<String>>? onValuesChanged;
  final CoilMotion? motion;
  final String? initial;
  final ValueChanged<String>? onChanged;
  final CoilPresentation? presentation;
  final bool autofocus;

  @override
  State<SelectDemo> createState() => SelectDemoState();
}

class SelectDemoState extends State<SelectDemo> {
  late String? value = widget.initial;
  late Set<String> values = widget.initialValues;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fruit',
              style: theme.typography.style(
                metrics.body,
                weight: CoilWeight.semibold,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 220,
              child: widget.multiple
                  ? CoilMultiSelect<String>(
                      key: const ValueKey('select'),
                      autofocus: widget.autofocus,
                      options: widget.options,
                      values: values,
                      presentation: widget.presentation,
                      motion: widget.motion,
                      sheetTitle: const Text('Fruit'),
                      onChanged: (next) {
                        setState(() => values = next);
                        widget.onValuesChanged?.call(next);
                      },
                    )
                  : CoilSelect<String>(
                      key: const ValueKey('select'),
                      autofocus: widget.autofocus,
                      options: widget.options,
                      value: value,
                      presentation: widget.presentation,
                      motion: widget.motion,
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
