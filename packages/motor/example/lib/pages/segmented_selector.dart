import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A segmented control whose selection indicator slides between options.
///
/// The indicator is a single [Rect] animated with a spring — left and width
/// settle independently, so the thumb stretches subtly as it travels.
class SegmentedSelectorPage extends StatefulWidget {
  const SegmentedSelectorPage({super.key});
  static const routeName = 'Segmented Selector';

  @override
  State<SegmentedSelectorPage> createState() => _SegmentedSelectorPageState();
}

class _SegmentedSelectorPageState extends State<SegmentedSelectorPage> {
  static const _segments = ['Overview', 'Activity', 'Saved'];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: SegmentedSelectorPage.routeName,
      description:
          'A tab selector built on a Rect track. Tapping a segment springs the '
          'indicator to its new bounds — width and position animate '
          'independently for a natural, slightly elastic slide.',
      child: Column(
        children: [
          Surface(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 44,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segWidth = constraints.maxWidth / _segments.length;
                  final target = Rect.fromLTWH(
                    _selected * segWidth,
                    0,
                    segWidth,
                    44,
                  );
                  return Stack(
                    children: [
                      MotionBuilder<Rect>(
                        value: target,
                        motion: const CupertinoMotion.bouncy(extraBounce: .05),
                        converter: MotionConverter.rect,
                        builder: (context, rect, _) => Positioned.fromRect(
                          rect: rect,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: t.surfaceSolid,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: t.hairlineShadow,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final (i, label) in _segments.indexed)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _selected = i),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: i == _selected
                                          ? t.textPrimary
                                          : t.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _segments[_selected],
                    style: TextStyle(
                      fontFamily: 'Archivo',
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.6,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      width: i.isEven ? double.infinity : 200,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.fog,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
