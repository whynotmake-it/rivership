import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app() => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light,
    child: Overlay.wrap(
      child: const FocusScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: Column(
              children: [
                _Controlled(ValueKey('stepped'), divisions: 4),
                _Controlled(ValueKey('continuous')),
                _Controlled(ValueKey('range'), divisions: 4, range: true),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

class _Controlled extends StatefulWidget {
  const _Controlled(Key key, {this.divisions, this.range = false})
    : super(key: key);

  final int? divisions;
  final bool range;

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  double value = 0;
  CoilRangeValues values = const CoilRangeValues(0, 1);

  @override
  Widget build(BuildContext context) => widget.range
      ? CoilRangeSlider(
          values: values,
          valueDisplay: CoilSliderValueDisplay.tooltip,
          divisions: widget.divisions,
          onChanged: (v) => setState(() => values = v),
        )
      : CoilSlider(
          value: value,
          divisions: widget.divisions,
          label: const Text('Volume'),
          onChanged: (v) => setState(() => value = v),
        );
}

void main() {
  testWidgets(
    'a stepped slider ticks once per move to another step by pointer, only',
    (tester) async {
      final clicks = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            clicks.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(_app());

      Offset at(String key, double fraction) {
        final r = tester.getRect(find.byKey(ValueKey(key)));
        return Offset(r.left + r.width * fraction, r.center.dy);
      }

      Future<void> drag(String key, List<double> fractions) async {
        final g = await tester.startGesture(at(key, fractions.first));
        await tester.pump();
        for (final f in fractions.skip(1)) {
          await g.moveTo(at(key, f));
          await tester.pump();
        }
        await g.up();
        await tester.pumpAndSettle();
      }

      // Pressing on the current step does nothing; then three steps up.
      await drag('stepped', [.05, .3, .55, .8]);
      expect(clicks, hasLength(3));
      expect(clicks.toSet(), {'HapticFeedbackType.selectionClick'});

      // Several steps in a single move play once, and dragging on past the
      // end, where the value stays, plays nothing more.
      clicks.clear();
      await drag('stepped', [.8, .05]);
      expect(clicks, hasLength(1));
      clicks.clear();
      await drag('stepped', [.05, 1, 1.2]);
      expect(clicks, hasLength(1));

      // A tap that jumps to another step ticks.
      clicks.clear();
      await tester.tapAt(at('stepped', .55));
      await tester.pumpAndSettle();
      expect(clicks, hasLength(1));

      // Keys move the value silently.
      clicks.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(clicks, isEmpty);

      // A continuous slider never ticks.
      await drag('continuous', [.05, .3, .55, .8]);
      expect(clicks, isEmpty);

      // Each thumb of a stepped range slider ticks.
      await drag('range', [.0, .3]);
      expect(clicks, hasLength(1));
      await drag('range', [.95, .6]);
      expect(clicks, hasLength(2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
