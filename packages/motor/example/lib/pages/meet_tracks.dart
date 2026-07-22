import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// Introduces tracks as stable identity keys for independently animated values.
class MeetTracksPage extends StatefulWidget {
  const MeetTracksPage({super.key});

  static const routeName = 'Meet Tracks';

  @override
  State<MeetTracksPage> createState() => _MeetTracksPageState();
}

class _MeetTracksPageState extends State<MeetTracksPage>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);

  // A Track is an identity key: declare it once and reuse the instance.
  // Equal-looking tracks created per build are different tracks.
  final _pos = Track<Offset>(
    .offset,
    initial: const Offset(-110, 64),
    motion: .bouncySpring(),
  );
  final _scale = Track<double>(
    .single,
    initial: 0.72,
    motion: .smoothSpring(),
  );
  final _tint = Track<Color>(
    .colorRgb,
    initial: CupertinoColors.systemGrey,
    motion: .smoothSpring(),
  );

  bool _featured = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _featured = !_featured);
    _controller.animate([
      _pos.to(_featured ? Offset.zero : const Offset(-110, 64)),
      _scale.to(_featured ? 1.18 : 0.72),
      _tint.to(
        _featured ? ExampleTheme.spectrumRed : CupertinoColors.systemGrey,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ExampleTheme.of(context);
    return ExamplePage(
      title: MeetTracksPage.routeName,
      next: (label: 'Timelines & Steps', routeName: 'Timelines & Steps'),
      description:
          'A track gives one animated property a stable identity. Tap anywhere '
          'in the stage, then tap again mid-flight: three tracks redirect on '
          'one clock while each preserves its own velocity.',
      child: Column(
        children: [
          SizedBox(
            height: 300,
            child: Stage(
              label: 'Tap repeatedly',
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: SizedBox.expand(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final position = _controller.value<Offset>(_pos);
                      final scale = _controller.value<double>(_scale);
                      final tint = _controller.value<Color>(_tint);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: position,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 112,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: theme.softShadow,
                                ),
                                child: const Icon(
                                  CupertinoIcons.sparkles,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: _Readouts(
                              position: position,
                              scale: scale,
                              tint: tint,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const TakeawayText(
            'One controller unifies interruption: position, scale, and tint '
            'redirect coherently while carrying their own velocities.',
          ),
        ],
      ),
    );
  }
}

class _Readouts extends StatelessWidget {
  const _Readouts({
    required this.position,
    required this.scale,
    required this.tint,
  });

  final Offset position;
  final double scale;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: ExampleTheme.of(context).textSecondary,
      fontSize: 10,
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const ['monospace', 'Menlo'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'value(_pos)   ${position.dx.toStringAsFixed(1)}, '
          '${position.dy.toStringAsFixed(1)}',
          style: style,
        ),
        Text(
          'value(_scale) ${scale.toStringAsFixed(2)}',
          style: style,
        ),
        Text(
          'value(_tint)  #${tint.toARGB32().toRadixString(16).padLeft(8, '0')}',
          style: style,
        ),
      ],
    );
  }
}
