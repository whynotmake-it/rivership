import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Presence values to show, including a spring's overshoot past 1.
const _presences = [0.0, 0.25, 0.5, 0.75, 1.0, 1.1];

const _cell = 96.0;

/// A tile with hard edges and stripes, so blur, scale and offset all show.
class _Tile extends StatelessWidget {
  const _Tile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B1B1F), width: 3),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3D5AFE),
            Color(0xFF3D5AFE),
            Color(0xFFFFC400),
            Color(0xFFFFC400),
          ],
          stops: [0, 0.5, 0.5, 1],
          tileMode: TileMode.repeated,
          end: Alignment(-0.6, -0.6),
        ),
      ),
    );
  }
}

Widget _strip(MotionTransition transition) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final presence in _presences)
                SizedBox.square(
                  dimension: _cell,
                  child: Center(
                    child: Builder(
                      builder: (context) =>
                          transition.build(context, presence, const _Tile()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MotionTransition goldens', () {
    final transitions = {
      'blur_fade': const MotionTransition.blurFade(
        blur: 6,
        scale: 0.8,
        offset: Offset(0, 16),
      ),
      'scale': const MotionTransition.scale(0.5),
      'slide': const MotionTransition.slide(Offset(0.5, 0)),
    };

    for (final MapEntry(key: name, value: transition) in transitions.entries) {
      testWidgets('$name at presence ${_presences.join(', ')}', (tester) async {
        tester.view
          ..physicalSize = Size(_cell * _presences.length, _cell)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_strip(transition));
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('golden/motion_transition_$name.png'),
        );
      });
    }
  });
}
