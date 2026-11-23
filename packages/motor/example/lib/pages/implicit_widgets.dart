import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/code_block.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/style.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Spring versions of Flutter's implicit animation widgets, side by side
/// with the originals.
class ImplicitWidgetsPage extends StatefulWidget {
  const ImplicitWidgetsPage({super.key});

  @override
  State<ImplicitWidgetsPage> createState() => _ImplicitWidgetsPageState();
}

enum _Feel {
  smooth('Smooth', 'smoothSpring', Motion.smoothSpring()),
  snappy('Snappy', 'snappySpring', Motion.snappySpring()),
  bouncy('Bouncy', 'bouncySpring', Motion.bouncySpring());

  const _Feel(this.label, this.call, this.motion);

  final String label;
  final String call;
  final Motion motion;
}

typedef _Status = ({Glyph glyph, String label});

const _statuses = <_Status>[
  (glyph: Glyph.check, label: 'Saved'),
  (glyph: Glyph.cloudUpload, label: 'Uploading 3 files'),
  (glyph: Glyph.cloudOff, label: "Can't reach the server. Retrying"),
];

class _ImplicitWidgetsPageState extends State<ImplicitWidgetsPage> {
  var _feel = _Feel.smooth;
  var _end = false;
  var _status = 0;
  var _count = 0;
  var _direction = 1;
  var _expanded = false;
  var _turned = false;
  var _pressed = false;
  var _visible = true;

  /// Slides each number in from the direction of the change and the old one
  /// out the other way, driven by the same presence the fade uses.
  late final AnimatedSwitcherTransitionBuilder _slide = (child, presence) {
    return ListenableBuilder(
      listenable: presence,
      child: child,
      builder: (context, child) {
        final entering = presence.status != AnimationStatus.reverse;
        final p = presence.value;
        final away = (1 - p) * (entering ? _direction : -_direction);
        return FractionalTranslation(
          translation: Offset(0, away * 0.6),
          child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
        );
      },
    );
  };

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).gap;
    final theme = CoilTheme.motionOf(context);
    final motion = _feel.motion;
    final call = '.${_feel.call}()';
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    final status = _statuses[_status];
    final nextStatus = () => setState(() {
      _status = (_status + 1) % _statuses.length;
    });
    final flip = () => setState(() => _end = !_end);
    final alignment = _end ? Alignment.centerRight : Alignment.centerLeft;

    Widget section({
      required String title,
      required String caption,
      required Widget stage,
      required String code,
    }) {
      return Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(title, style: text.subtitle.copyWith(fontWeight: text.emphasis)),
          const SizedBox(height: 4),
          Text(caption, style: text.muted.caption),
          const SizedBox(height: 12),
          DemoStage(child: stage),
          SizedBox(height: gap),
          CodeBlock(code),
        ],
      );
    }

    Widget dot(Color color) => DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: const CircleBorder()),
      child: const SizedBox.square(dimension: 28),
    );

    Widget track({required Widget dot}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: flip,
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ColoredBox(
              color: colors.border,
              child: const SizedBox(height: 1, width: double.infinity),
            ),
            dot,
          ],
        ),
      ),
    );

    Widget pill(Widget switcher) => DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface(4),
        shape: RoundedSuperellipseBorder(
          borderRadius: .circular(999),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 14, vertical: 8),
        child: switcher,
      ),
    );

    Widget statusLabel(_Status status, int index) => Row(
      key: ValueKey(index),
      mainAxisSize: .min,
      children: [
        GlyphIcon(status.glyph, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            status.label,
            style: text.body.copyWith(color: colors.foreground),
          ),
        ),
      ],
    );

    Widget tile({required Widget child}) => DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface(4),
        shape: RoundedSuperellipseBorder(
          borderRadius: .circular(radii.item),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: SizedBox.square(dimension: 48, child: Center(child: child)),
    );

    Widget helper(String name, String hint, Widget demo) => Column(
      crossAxisAlignment: .center,
      children: [
        SizedBox(height: 56, child: Center(child: demo)),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: mono(text.caption.fontSize ?? 12, color: colors.foreground),
        ),
        Text(hint, textAlign: TextAlign.center, style: text.muted.caption),
      ],
    );

    return GalleryPage(
      title: chapterNamed('Implicit widgets').title,
      lead:
          'motor_widgets has spring versions of Flutter\'s implicit animation '
          'widgets. Change a value while it is still moving and compare: a '
          'spring keeps the speed it has instead of starting over.',
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilTabs<_Feel>(
            value: _feel,
            onChanged: (feel) => setState(() => _feel = feel),
            tabs: [
              for (final feel in _Feel.values)
                CoilTab(value: feel, label: Text(feel.label)),
            ],
          ),
        ),
        section(
          title: 'Interrupt it',
          caption:
              'Tap Switch side again before the dots arrive. Flutter\'s '
              'starts its curve over from a standstill; the spring turns '
              'around with the speed it has.',
          stage: _Comparison(
            control: CoilButton(
              variant: .secondary,
              size: .compact,
              leading: const GlyphIcon(Glyph.repeat),
              onPressed: flip,
              child: const Text('Switch side'),
            ),
            flutter: _Side(
              name: 'AnimatedAlign',
              kind: 'Flutter',
              child: track(
                dot: AnimatedAlign(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  alignment: alignment,
                  child: dot(colors.mutedForeground),
                ),
              ),
            ),
            motor: _Side(
              name: 'MotionAlign',
              kind: 'motor_widgets',
              child: track(
                dot: MotionAlign(
                  motion: motion,
                  debugLabel: 'Dot',
                  alignment: alignment,
                  child: dot(colors.brand),
                ),
              ),
            ),
          ),
          code:
              '// Flutter: a new 500 ms curve on every change.\n'
              'AnimatedAlign(\n'
              '  duration: .new(milliseconds: 500),\n'
              '  curve: Curves.easeInOut,\n'
              '  alignment: ${_end ? '.centerRight' : '.centerLeft'},\n'
              '  child: dot,\n'
              ')\n'
              '\n'
              '// motor_widgets: the spring keeps its velocity.\n'
              'MotionAlign(\n'
              '  motion: $call,\n'
              '  alignment: ${_end ? '.centerRight' : '.centerLeft'},\n'
              '  child: dot,\n'
              ')',
        ),
        section(
          title: 'Size switcher',
          caption:
              'Tap Next status quickly. Flutter\'s box keeps the larger size '
              'until the old label has faded out, then shrinks. '
              'MotionSizeSwitcher resizes as the labels cross-fade and keeps '
              'its speed when you tap again.',
          stage: _Comparison(
            control: CoilButton(
              variant: .secondary,
              size: .compact,
              leading: const GlyphIcon(Glyph.arrowRight),
              onPressed: nextStatus,
              child: const Text('Next status'),
            ),
            flutter: _Side(
              name: 'AnimatedSize + AnimatedSwitcher',
              kind: 'Flutter',
              child: pill(
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: statusLabel(status, _status),
                  ),
                ),
              ),
            ),
            motor: _Side(
              name: 'MotionSizeSwitcher',
              kind: 'motor_widgets',
              child: pill(
                MotionSizeSwitcher(
                  motion: theme.fade,
                  sizeMotion: motion,
                  immediateResize: true,
                  debugLabel: 'Status pill',
                  transitionBuilder: CoilBlurFade.transition(),
                  child: statusLabel(status, _status),
                ),
              ),
            ),
          ),
          code:
              '// Flutter: fades, and the size follows the stack.\n'
              'AnimatedSize(\n'
              '  duration: .new(milliseconds: 300),\n'
              '  child: AnimatedSwitcher(\n'
              '    duration: .new(milliseconds: 300),\n'
              '    child: Label(key: ValueKey(status)),\n'
              '  ),\n'
              ')\n'
              '\n'
              '// motor_widgets: switches at once, resizes during the fade.\n'
              'MotionSizeSwitcher(\n'
              '  immediateResize: true,\n'
              '  sizeMotion: $call,\n'
              '  motion: fade,\n'
              '  transitionBuilder: CoilBlurFade.transition(),\n'
              '  child: Label(key: ValueKey(status)),\n'
              ')',
        ),
        section(
          title: 'Counter',
          caption:
              'Tap − or + quickly. Each number slides in from the direction '
              'of the change while the old one leaves, and a fast tap '
              'carries the motion on instead of restarting it.',
          stage: Padding(
            padding: const .all(16),
            child: Center(
              child: Row(
                mainAxisSize: .min,
                spacing: 16,
                children: [
                  CoilButton.icon(
                    variant: .secondary,
                    size: .compact,
                    semanticLabel: 'Decrease',
                    icon: const GlyphIcon(Glyph.minus),
                    onPressed: () => setState(() {
                      _direction = -1;
                      _count--;
                    }),
                  ),
                  SizedBox(
                    width: 96,
                    child: ClipRect(
                      child: MotionSwitcher(
                        motion: motion,
                        debugLabel: 'Counter',
                        transitionBuilder: _slide,
                        child: FittedBox(
                          key: ValueKey(_count),
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$_count',
                            maxLines: 1,
                            style: text.display.tabular,
                          ),
                        ),
                      ),
                    ),
                  ),
                  CoilButton.icon(
                    variant: .secondary,
                    size: .compact,
                    semanticLabel: 'Increase',
                    icon: const GlyphIcon(Glyph.plus),
                    onPressed: () => setState(() {
                      _direction = 1;
                      _count++;
                    }),
                  ),
                ],
              ),
            ),
          ),
          code:
              'MotionSwitcher(\n'
              '  motion: $call,\n'
              '  transitionBuilder: slideAndFade,\n'
              '  child: Text(\n'
              "    '$_count',\n"
              '    key: ValueKey($_count),\n'
              '  ),\n'
              ')',
        ),
        section(
          title: 'One spring per property',
          caption:
              'Toggle twice quickly: the size and the color each keep their '
              'own spring.',
          stage: Padding(
            padding: const .all(16),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                SizedBox(
                  height: 112,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: MotionContainer(
                        motion: motion,
                        motions: {
                          MotionContainerTrack.color: theme.fade,
                          MotionContainerTrack.minWidth: const .bouncySpring(),
                          MotionContainerTrack.maxWidth: const .bouncySpring(),
                          MotionContainerTrack.minHeight: const .bouncySpring(),
                          MotionContainerTrack.maxHeight: const .bouncySpring(),
                        },
                        debugLabel: 'Square',
                        width: _expanded ? 160 : 64,
                        height: _expanded ? 96 : 64,
                        decoration: BoxDecoration(
                          color: _expanded ? colors.foreground : colors.accent,
                          borderRadius: .circular(
                            _expanded ? radii.container : radii.item,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: CoilButton(
                    variant: .secondary,
                    size: .compact,
                    leading: const GlyphIcon(Glyph.move),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Shrink' : 'Expand'),
                  ),
                ),
              ],
            ),
          ),
          code:
              'MotionContainer(\n'
              '  motion: $call,\n'
              '  motions: {\n'
              '    .color: fade,\n'
              '    .minWidth: .bouncySpring(),\n'
              '    .maxWidth: .bouncySpring(),\n'
              '    .minHeight: .bouncySpring(),\n'
              '    .maxHeight: .bouncySpring(),\n'
              '  },\n'
              '  width: ${_expanded ? 160 : 64},\n'
              '  height: ${_expanded ? 96 : 64},\n'
              '  decoration: BoxDecoration(\n'
              '    color: ${_expanded ? 'foreground' : 'accent'},\n'
              '    borderRadius: .circular(${_expanded ? 'container' : 'item'}),\n'
              '  ),\n'
              ')',
        ),
        section(
          title: 'Small helpers',
          caption:
              'Tap the chevron and the dot, press and hold the tile. Each '
              'one retargets mid-flight without a controller.',
          stage: Padding(
            padding: const .all(16),
            child: Row(
              crossAxisAlignment: .start,
              spacing: 8,
              children: [
                Expanded(
                  child: helper(
                    'MotionRotation',
                    'Tap',
                    GestureDetector(
                      onTap: () => setState(() => _turned = !_turned),
                      child: tile(
                        child: MotionRotation(
                          turns: _turned ? 0.5 : 0,
                          motion: motion,
                          debugLabel: 'Chevron',
                          child: const GlyphIcon(Glyph.chevronDown, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: helper(
                    'MotionScale',
                    'Press and hold',
                    GestureDetector(
                      onTapDown: (_) => setState(() => _pressed = true),
                      onTapUp: (_) => setState(() => _pressed = false),
                      onTapCancel: () => setState(() => _pressed = false),
                      child: MotionScale(
                        scale: _pressed ? 0.8 : 1,
                        motion: motion,
                        debugLabel: 'Tile',
                        child: tile(child: dot(colors.foreground)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: helper(
                    'MotionOpacity',
                    'Tap',
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _visible = !_visible),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  shape: CircleBorder(
                                    side: BorderSide(color: colors.border),
                                  ),
                                ),
                                child: const SizedBox.square(dimension: 28),
                              ),
                              MotionOpacity(
                                opacity: _visible ? 1 : 0,
                                motion: motion,
                                debugLabel: 'Dot',
                                child: dot(colors.brand),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          code:
              'MotionRotation(\n'
              '  motion: $call,\n'
              '  turns: ${_turned ? 0.5 : 0},\n'
              '  child: chevron,\n'
              ')\n'
              '\n'
              'MotionScale(\n'
              '  motion: $call,\n'
              '  scale: ${_pressed ? 0.8 : 1},\n'
              '  child: tile,\n'
              ')\n'
              '\n'
              'MotionOpacity(\n'
              '  motion: $call,\n'
              '  opacity: ${_visible ? 1 : 0},\n'
              '  child: dot,\n'
              ')',
        ),
        NextChapter(next: chapterNamed('Implicit widgets').next!),
      ],
    );
  }
}

/// Two demos side by side on a stage of 560 or more, stacked below it, with
/// the one control under both.
class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.flutter,
    required this.motor,
    required this.control,
  });

  final Widget flutter;
  final Widget motor;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Padding(
      padding: const .all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          return Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: .start,
                  spacing: 24,
                  children: [
                    Expanded(child: flutter),
                    Expanded(child: motor),
                  ],
                )
              else ...[
                flutter,
                const SizedBox(height: 12),
                ColoredBox(
                  color: colors.border,
                  child: const SizedBox(height: 1),
                ),
                const SizedBox(height: 12),
                motor,
              ],
              const SizedBox(height: 16),
              Center(child: control),
            ],
          );
        },
      ),
    );
  }
}

/// One half of a comparison: the widget's name and where it comes from at
/// the top, the demo centered under them.
class _Side extends StatelessWidget {
  const _Side({required this.name, required this.kind, required this.child});

  final String name;
  final String kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(
          name,
          style: mono(text.caption.fontSize ?? 12, color: colors.foreground),
        ),
        Text(kind, style: text.muted.caption),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Center(child: child),
        ),
      ],
    );
  }
}
