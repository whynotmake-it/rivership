import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The interaction states every overview sheet shows, as columns.
enum SheetState {
  rest('rest', {}),
  hover('hover', {WidgetState.hovered}),
  focus('focus', {WidgetState.focused}),
  pressed('pressed', {WidgetState.hovered, WidgetState.pressed}),
  disabled('disabled', {});

  const SheetState(this.label, this.states);

  final String label;
  final Set<WidgetState> states;

  bool get isDisabled => this == SheetState.disabled;

  WidgetStatesController controller() => WidgetStatesController({...states});
}

/// Builds one cell of a sheet for [state].
typedef SheetCellBuilder = Widget Function(SheetState state);

/// One row of a sheet: a label and a cell per column.
class SheetRow {
  const SheetRow(this.label, this.cell);

  final String label;
  final SheetCellBuilder cell;
}

/// A titled table of [rows] × [SheetState] columns.
class StateTable extends StatelessWidget {
  const StateTable({
    required this.rows,
    super.key,
    this.columns = SheetState.values,
  });

  final List<SheetRow> rows;
  final List<SheetState> columns;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context).colors;
    final caption = FluidTypography.style(
      FluidSizes.desktop.caption,
      color: colors.mutedForeground,
    );
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox(),
            for (final c in columns)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(c.label, style: caption),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(row.label, style: caption),
              ),
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: row.cell(c),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A light panel and a dark panel side by side, each showing [builder].
class ThemedPair extends StatelessWidget {
  const ThemedPair({
    required this.title,
    required this.builder,
    super.key,
    this.tier = FluidTier.desktop,
    this.direction = Axis.horizontal,
  });

  final String title;
  final WidgetBuilder builder;
  final FluidTier tier;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final theme in [FluidThemeData.light, FluidThemeData.dark])
          SheetPanel(
            title: '$title · ${theme.brightness.name}',
            theme: theme.copyWith(tier: tier),
            child: Builder(builder: builder),
          ),
      ],
    );
  }
}

/// A themed panel with a title.
class SheetPanel extends StatelessWidget {
  const SheetPanel({
    required this.title,
    required this.theme,
    required this.child,
    super.key,
  });

  final String title;
  final FluidThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FluidTheme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = FluidTheme.of(context).colors;
          return ColoredBox(
            color: colors.background,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FluidTypography.style(
                      const FluidTypeStep(14, 20),
                      weight: FluidWeight.semibold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

final _sheetKey = GlobalKey();

/// Pumps [sheet] at 2x device pixel ratio (like the web references), lets
/// every animation and post-frame measurement settle, and returns a finder
/// for the sheet's repaint boundary.
Future<Finder> pumpSheet(
  WidgetTester tester,
  Widget sheet, {
  Size surface = const Size(3000, 2400),
}) async {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = surface * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF6B97FF),
      debugShowCheckedModeBanner: false,
      builder: (context, _) => withOverlay(
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: _sheetKey, child: sheet),
        ),
      ),
    ),
  );
  await settle(tester);
  return find.byKey(_sheetKey);
}

/// Pumps long enough for springs and post-frame measurements to settle,
/// without `pumpAndSettle` (a loading spinner loops forever).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Wraps [child] in an [Overlay], which [EditableText] needs (a bare
/// `WidgetsApp.builder` has no Navigator, so no Overlay).
Widget withOverlay(Widget child) => Overlay(
  initialEntries: [OverlayEntry(builder: (_) => child)],
);

/// Compares the [RepaintBoundary] found by [finder] against the golden at
/// [path], rendered at 2x like the web references (`matchesGoldenFile` on a
/// finder captures at 1x).
Future<void> expectSheetGolden(
  WidgetTester tester,
  Finder finder,
  String path,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  addTearDown(() => image?.dispose());
  await expectLater(image, matchesGoldenFile(path));
}
