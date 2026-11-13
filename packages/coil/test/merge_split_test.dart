import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/golden_sheet.dart';

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
              children: [for (final r in _rows) Text(r)],
            ),
          ),
          CoilToggleGroup(
            values: selected,
            onChanged: (v) => selection.value = v,
            children: [for (final d in _days) Text(d)],
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

/// The selection blocks the first group's painter holds.
int _blocks(WidgetTester tester) => tester
    .renderObject<RenderCoilMotionLayer>(find.byType(CoilMotionLayer).first)
    .background
    .whereType<CoilSelectionPainter>()
    .single
    .debugBlockCount;

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
    testWidgets('merge converges two blocks, then commits to one', (
      tester,
    ) async {
      final selection = ValueNotifier<Set<int>>({0, 1, 3, 4});
      addTearDown(selection.dispose);
      await pumpSheet(tester, _sheet(selection));
      expect(_blocks(tester), 2);

      selection.value = {0, 1, 2, 3, 4};
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_blocks(tester), 2, reason: 'both halves converge on the seam');
      await settle(tester);
      expect(_blocks(tester), 1, reason: 'committed to one block');
    });

    testWidgets('split starts at the seam and diverges into two', (
      tester,
    ) async {
      final selection = ValueNotifier<Set<int>>({0, 1, 2, 3, 4});
      addTearDown(selection.dispose);
      await pumpSheet(tester, _sheet(selection));
      expect(_blocks(tester), 1);

      selection.value = {0, 1, 3, 4};
      await tester.pump();
      expect(_blocks(tester), 2);
      await settle(tester);
      expect(_blocks(tester), 2);
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
