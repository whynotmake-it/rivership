import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/style.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Spring versions of Flutter's implicit animation widgets.
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

enum _Example { sizeSwitcher, container, size }

const _counts = [1, 12, 128, 1280];

class _ImplicitWidgetsPageState extends State<ImplicitWidgetsPage> {
  final _code = ValueNotifier('');

  var _feel = _Feel.smooth;
  var _example = _Example.sizeSwitcher;
  var _countIndex = 0;
  var _expanded = false;
  var _more = false;

  @override
  void initState() {
    super.initState();
    _updateCode();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _updateCode() {
    final motion = '.${_feel.call}()';
    _code.value = switch (_example) {
      _Example.sizeSwitcher =>
        '// The label cross-fades and the width springs.\n'
            'MotionSizeSwitcher(\n'
            '  motion: $motion,\n'
            '  child: Text(\n'
            "    '${_label(_counts[_countIndex])}',\n"
            '    key: ValueKey(${_counts[_countIndex]}),\n'
            '  ),\n'
            ')',
      _Example.container =>
        '// Each property springs on its own track.\n'
            'MotionContainer(\n'
            '  motion: $motion,\n'
            '  width: ${_expanded ? 128 : 64},\n'
            '  height: 64,\n'
            '  decoration: BoxDecoration(\n'
            '    color: ${_expanded ? 'foreground' : 'muted'},\n'
            '    borderRadius: .circular(${_expanded ? 'container' : 'item'}),\n'
            '  ),\n'
            ')',
      _Example.size =>
        '// Follows its child\'s size, with velocity.\n'
            'MotionSize(\n'
            '  motion: $motion,\n'
            '  alignment: .topLeft,\n'
            '  child: ${_more ? 'paragraph' : 'SizedBox(width: .infinity)'},\n'
            ')',
    };
  }

  void _touch(_Example example, VoidCallback change) {
    setState(() {
      _example = example;
      change();
    });
    _updateCode();
  }

  static String _label(int count) => count == 1 ? '1 item' : '$count items';

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).gap;
    final motion = _feel.motion;
    return ChapterPage(
      chapter: chapterNamed('Implicit widgets'),
      lead:
          'motor_widgets has spring versions of Flutter\'s implicit animation '
          'widgets. Tap quickly: a change mid-flight keeps its velocity '
          'instead of starting over.',
      code: _code,
      stageHeight: 440,
      stage: LayoutBuilder(
        builder: (context, constraints) {
          const inset = 16.0;
          const spacing = 24.0;
          final wide = constraints.maxWidth >= 600;
          final width = constraints.maxWidth - 2 * inset;
          final cell = wide ? (width - 2 * spacing) / 3 : width;
          return SingleChildScrollView(
            padding: const .all(inset),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                CoilTabs<_Feel>(
                  value: _feel,
                  onChanged: (feel) {
                    setState(() => _feel = feel);
                    _updateCode();
                  },
                  tabs: [
                    for (final feel in _Feel.values)
                      CoilTab(value: feel, label: Text(feel.label)),
                  ],
                ),
                SizedBox(height: spacing),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _Cell(
                      width: cell,
                      label: 'MotionSizeSwitcher',
                      child: _Counter(
                        motion: motion,
                        count: _counts[_countIndex],
                        gap: gap,
                        onFewer: _countIndex == 0
                            ? null
                            : () => _touch(
                                _Example.sizeSwitcher,
                                () => _countIndex--,
                              ),
                        onMore: _countIndex == _counts.length - 1
                            ? null
                            : () => _touch(
                                _Example.sizeSwitcher,
                                () => _countIndex++,
                              ),
                      ),
                    ),
                    _Cell(
                      width: cell,
                      label: 'MotionContainer',
                      child: _Square(
                        motion: motion,
                        expanded: _expanded,
                        gap: gap,
                        onToggle: () => _touch(
                          _Example.container,
                          () => _expanded = !_expanded,
                        ),
                      ),
                    ),
                    _Cell(
                      width: cell,
                      label: 'MotionSize',
                      child: _Reveal(
                        motion: motion,
                        open: _more,
                        gap: gap,
                        onToggle: () =>
                            _touch(_Example.size, () => _more = !_more),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A demo with the widget's name above it.
class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.label, required this.child});

  final double width;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(label, style: mono(11, color: colors.mutedForeground)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.motion,
    required this.count,
    required this.gap,
    required this.onFewer,
    required this.onMore,
  });

  final Motion motion;
  final int count;
  final double gap;
  final VoidCallback? onFewer;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.surface(4),
            shape: RoundedSuperellipseBorder(
              borderRadius: .circular(radii.item),
              side: BorderSide(color: colors.border),
            ),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 16, vertical: 10),
            child: MotionSizeSwitcher(
              motion: motion,
              debugLabel: 'Counter pill',
              child: Text(
                count == 1 ? '1 item' : '$count items',
                key: ValueKey(count),
                maxLines: 1,
                style: text.body.tabular,
              ),
            ),
          ),
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: .min,
          spacing: gap,
          children: [
            CoilButton.icon(
              variant: .secondary,
              size: .compact,
              semanticLabel: 'Fewer items',
              icon: const GlyphIcon(Glyph.minus),
              onPressed: onFewer,
            ),
            CoilButton.icon(
              variant: .secondary,
              size: .compact,
              semanticLabel: 'More items',
              icon: const GlyphIcon(Glyph.plus),
              onPressed: onMore,
            ),
          ],
        ),
      ],
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({
    required this.motion,
    required this.expanded,
    required this.gap,
    required this.onToggle,
  });

  final Motion motion;
  final bool expanded;
  final double gap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        SizedBox(
          height: 64,
          child: Align(
            alignment: .centerLeft,
            child: GestureDetector(
              onTap: onToggle,
              child: MotionContainer(
                motion: motion,
                debugLabel: 'Square',
                width: expanded ? 128 : 64,
                height: 64,
                // A BoxDecoration's color and radius spring; other
                // decorations change at once.
                decoration: BoxDecoration(
                  color: expanded ? colors.foreground : colors.muted,
                  borderRadius: .circular(
                    expanded ? radii.container : radii.item,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: gap),
        CoilButton(
          variant: .secondary,
          size: .compact,
          onPressed: onToggle,
          child: const Text('Toggle'),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.motion,
    required this.open,
    required this.gap,
    required this.onToggle,
  });

  final Motion motion;
  final bool open;
  final double gap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        CoilButton(
          variant: .secondary,
          size: .compact,
          onPressed: onToggle,
          child: Text(open ? 'Show less' : 'Show more'),
        ),
        MotionSize(
          motion: motion,
          debugLabel: 'Paragraph size',
          alignment: .topLeft,
          child: open
              ? Padding(
                  padding: EdgeInsets.only(top: gap),
                  child: Text(
                    'MotionSize springs to its child\'s size. When its '
                    'constraints change, it follows at once, so a resized '
                    'window never lags.',
                    style: text.muted.body,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
