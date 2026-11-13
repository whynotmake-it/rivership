import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/golden_sheet.dart';
import 'src/paint_probe.dart';

const _rows = [
  'Inbox',
  'Drafts',
  'Sent',
  'Archive',
  'Spam',
  'Trash',
  'Notes',
  'Tasks',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'All'];

/// Runs of 1, 2 and 3 with gaps between them.
const _runs123 = {0, 2, 3, 5, 6, 7};

/// One panel: a checkbox group and a toggle row bound to [selection].
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.theme,
    required this.selection,
  });

  final String title;
  final CoilThemeData theme;
  final ValueNotifier<Set<int>> selection;

  @override
  Widget build(BuildContext context) => SheetPanel(
    title: title,
    theme: theme,
    child: ValueListenableBuilder(
      valueListenable: selection,
      builder: (context, selected, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          SizedBox(
            width: 220,
            child: CoilCheckboxGroup(
              values: selected,
              onChanged: (v) => selection.value = v,
              options: [
                for (final (i, r) in _rows.indexed)
                  CoilOption(value: i, label: r),
              ],
            ),
          ),
          CoilToggleGroup(
            values: selected,
            onChanged: (v) => selection.value = v,
            options: [
              for (final (i, d) in _days.indexed)
                CoilOption(value: i, label: d),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _sheet(ValueNotifier<Set<int>> selection) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final tier in CoilTier.values)
      for (final theme in [CoilThemeData.light, CoilThemeData.dark])
        _Panel(
          title: '${tier.name} · ${theme.brightness.name}',
          theme: theme.copyWith(tier: tier),
          selection: selection,
        ),
  ],
);

const _red = Color(0xFFFF0000);
final _boundary = find.byKey(const ValueKey('boundary'));

/// Five 36 px rows with a red selection painter (square corners), bound to
/// [selection], with [motion] as the theme's tokens.
class _Rows extends StatefulWidget {
  const _Rows({required this.selection, required this.motion});

  final Set<int> selection;
  final CoilMotion motion;

  @override
  State<_Rows> createState() => _RowsState();
}

class _RowsState extends State<_Rows> {
  @override
  Widget build(BuildContext context) {
    final blocks = CoilSelectionBlocks(
      selected: widget.selection,
      color: _red,
      radius: 0,
      motion: widget.motion,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: const ValueKey('boundary'),
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: CoilMotionLayer(
                background: [blocks],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 5; i++)
                      CoilMotionTarget(
                        index: i,
                        child: const SizedBox(height: 36),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the pixel at height [y] (in the rows' column) is selection-red.
Future<bool> _redAt(WidgetTester tester, double y) async =>
    isNear(await colorAt(tester, _boundary, Offset(50, y)), _red);

void main() {
  group('CoilSelectionRuns', () {
    test('groups contiguous items and keeps ids stable', () {
      final runs = CoilSelectionRuns();
      final first = runs.update({0, 1, 3, 4});
      expect(first.map((r) => (r.start, r.end)), [(0, 1), (3, 4)]);
      final upper = first[0].id;

      // Merge: the joined run keeps the upper id.
      final merged = runs.update({0, 1, 2, 3, 4});
      expect(merged.single.id, upper);

      // Split: the upper part keeps it, the lower gets a new one.
      final split = runs.update({0, 1, 3, 4});
      expect(split[0].id, upper);
      expect(split[1].id, isNot(upper));
    });
  });

  group('CoilSelectionBackground', () {
    testWidgets('a merge follows a slower standard spring set at runtime', (
      tester,
    ) async {
      final slow = const CoilMotion().copyWith(
        standard: const Motion.linear(Duration(seconds: 1)),
      );
      await tester.pumpWidget(
        _Rows(selection: const {0, 1, 3, 4}, motion: slow),
      );
      expect(await _redAt(tester, 80), isFalse, reason: 'row 2 is the gap');

      await tester.pumpWidget(
        _Rows(selection: const {0, 1, 2, 3, 4}, motion: slow),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The upper half's edge glides from 72 to 90 over a second: at 400 ms
      // it hasn't reached 88, so the merge isn't done yet.
      expect(await _redAt(tester, 88), isFalse);
      await tester.pumpAndSettle();
      expect(await _redAt(tester, 80), isTrue);
      expect(await _redAt(tester, 100), isTrue);
    });

    testWidgets('reduced motion merges and splits at once', (tester) async {
      final reduced = const CoilMotion().reduced();
      await tester.pumpWidget(
        _Rows(selection: const {0, 1, 3, 4}, motion: reduced),
      );
      await tester.pumpWidget(
        _Rows(selection: const {0, 1, 2, 3, 4}, motion: reduced),
      );
      await tester.pump();
      await tester.pump();
      expect(await _redAt(tester, 80), isTrue);

      await tester.pumpWidget(
        _Rows(selection: const {0, 1, 3, 4}, motion: reduced),
      );
      await tester.pump();
      await tester.pump();
      expect(await _redAt(tester, 80), isFalse);
      expect(await _redAt(tester, 60), isTrue);
    });

    testWidgets('goldens: rest runs of 1, 2, 3; mid-merge; mid-split', (
      tester,
    ) async {
      final selection = ValueNotifier<Set<int>>(_runs123);
      addTearDown(selection.dispose);
      final sheet = await pumpSheet(tester, _sheet(selection));
      await expectSheetGolden(tester, sheet, 'goldens/merge_split_rest.png');

      // Merge: {0..1, 3..4} + 2.
      selection.value = {0, 1, 3, 4};
      await settle(tester);
      selection.value = {0, 1, 2, 3, 4};
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await expectSheetGolden(
        tester,
        sheet,
        'goldens/merge_split_merging_40ms.png',
      );
      await tester.pump(const Duration(milliseconds: 50));
      await expectSheetGolden(
        tester,
        sheet,
        'goldens/merge_split_merging_90ms.png',
      );
      await settle(tester);
      await expectSheetGolden(
        tester,
        sheet,
        'goldens/merge_split_merged.png',
      );

      // Split: {0..4} - 2.
      selection.value = {0, 1, 3, 4};
      // The halves start at the seam and diverge from the first frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await expectSheetGolden(
        tester,
        sheet,
        'goldens/merge_split_splitting_40ms.png',
      );
      await settle(tester);
    });
  });
}
