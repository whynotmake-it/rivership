import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/shell/devtools_switch.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/code_block.dart';

/// Turn on the tools and inspect something that is moving.
class DevToolsPage extends StatelessWidget {
  const DevToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).gap;
    final text = CoilTheme.textOf(context);
    return GalleryPage(
      title: 'DevTools',
      lead:
          'motor_devtools shows every motor animation on a timeline. Scrub '
          'it, slow it down, and tune a track\'s motion while the app runs.',
      children: [
        ValueListenableBuilder(
          valueListenable: devtoolsVisible,
          builder: (context, visible, _) => Align(
            alignment: .centerLeft,
            child: CoilSwitch(
              value: visible,
              onChanged: (value) => devtoolsVisible.value = value,
              label: const Text('Show DevTools'),
            ),
          ),
        ),
        const SizedBox(height: 200, child: DemoStage(child: _Pulse())),
        Column(
          crossAxisAlignment: .stretch,
          children: [
            Text(
              'Wrap your app. The tools run in debug builds; enabled: true '
              'turns them on in release builds too, and '
              '--dart-define=MOTOR_DEVTOOLS=false leaves them out of a build.',
              style: text.muted.body,
            ),
            SizedBox(height: gap),
            const CodeBlock(
              'MotorDevTools(\n  enabled: true,\n  child: app,\n)',
            ),
          ],
        ),
        Column(
          crossAxisAlignment: .stretch,
          children: [
            Text(
              'Name controllers and tracks so the timeline shows them by name.',
              style: text.muted.body,
            ),
            SizedBox(height: gap),
            const CodeBlock(
              "TrackBuilder(\n  debugLabel: 'Checkout card',\n  …\n)",
            ),
          ],
        ),
      ],
    );
  }
}

/// Three dots pulsing in turn: something named for the tools to show.
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> {
  final _dots = [
    for (var i = 1; i <= 3; i++)
      Track<double>(.single, initial: 0, debugLabel: 'Dot $i'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Center(
      child: TrackBuilder(
        debugLabel: 'Pulse',
        animations: [
          for (final (i, dot) in _dots.indexed)
            dot([
              .hold(Duration(milliseconds: 160 * i)),
              .loop([
                .to(
                  1,
                  motion: .smoothSpring(
                    duration: const Duration(milliseconds: 600),
                  ),
                ),
                .to(
                  0,
                  motion: .smoothSpring(
                    duration: const Duration(milliseconds: 600),
                  ),
                ),
              ]),
            ]),
        ],
        builder: (context, value, _) => Row(
          mainAxisSize: .min,
          spacing: 20,
          children: [
            for (final dot in _dots)
              Opacity(
                opacity: .35 + .65 * value(dot).clamp(0, 1),
                child: Transform.scale(
                  scale: .6 + .5 * value(dot),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.foreground,
                      shape: const CircleBorder(),
                    ),
                    child: const SizedBox.square(dimension: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
