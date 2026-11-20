import 'package:coil/coil.dart';
import 'package:coil/src/primitives/selection_blocks.dart'
    show CoilSelectionRuns;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'src/paint_probe.dart';

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
  });
}
