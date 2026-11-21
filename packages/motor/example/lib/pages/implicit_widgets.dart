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
            '    color: ${_expanded ? 'foreground' : 'accent'},\n'
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
    // Under 900 the stage can be under 600 wide, where the cells stack.
    final stacked = MediaQuery.sizeOf(context).width < 900;
    return ChapterPage(
      chapter: chapterNamed('Implicit widgets'),
      lead:
          'motor_widgets has spring versions of Flutter\'s implicit animation '
          'widgets. Tap quickly: a change mid-flight keeps its velocity '
          'instead of starting over.',
      code: _code,
      stageHeight: stacked ? 740 : 300,
      stage: LayoutBuilder(
        builder: (context, constraints) {
          const inset = 16.0;
          const spacing = 24.0;
          final wide = constraints.maxWidth >= 600;
          final cells = [
            _Cell(
              label: 'MotionSizeSwitcher',
              example: _Counter(
                motion: motion,
                count: _counts[_countIndex],
                gap: gap,
                onFewer: _countIndex == 0
                    ? null
                    : () => _touch(_Example.sizeSwitcher, () => _countIndex--),
                onMore: _countIndex == _counts.length - 1
                    ? null
                    : () => _touch(_Example.sizeSwitcher, () => _countIndex++),
              ),
            ),
            _Cell(
              label: 'MotionContainer',
              example: _Square(
                motion: motion,
                expanded: _expanded,
                onToggle: () =>
                    _touch(_Example.container, () => _expanded = !_expanded),
              ),
              control: CoilButton(
                variant: .secondary,
                size: .compact,
                onPressed: () =>
                    _touch(_Example.container, () => _expanded = !_expanded),
                child: const Text('Toggle'),
              ),
            ),
            _Cell(
              label: 'MotionSize',
              example: _Reveal(motion: motion, open: _more),
              control: CoilButton(
                variant: .secondary,
                size: .compact,
                onPressed: () => _touch(_Example.size, () => _more = !_more),
                child: Text(_more ? 'Show less' : 'Show more'),
              ),
            ),
          ];
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
                Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: wide
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.stretch,
                  spacing: spacing,
                  children: [
                    for (final cell in cells)
                      if (wide) Expanded(child: cell) else cell,
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

/// A demo: the widget's name at the top, the example centered in a fixed
/// area, and its control centered under it.
class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.example, this.control});

  /// The height every example is centered in.
  static const exampleHeight = 120.0;

  final String label;
  final Widget example;

  /// Under the example; the counter's buttons are part of the example.
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final gap = CoilTheme.metricsOf(context).gap;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(label, style: mono(11, color: colors.mutedForeground)),
        SizedBox(
          height: exampleHeight,
          child: ClipRect(child: Center(child: example)),
        ),
        if (control case final control?) ...[
          SizedBox(height: gap),
          Center(child: control),
        ],
      ],
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
    // Scales down rather than overflowing in a narrow cell or at large text.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
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
          CoilButton.icon(
            variant: .secondary,
            size: .compact,
            semanticLabel: 'More items',
            icon: const GlyphIcon(Glyph.plus),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({
    required this.motion,
    required this.expanded,
    required this.onToggle,
  });

  final Motion motion;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    return GestureDetector(
      onTap: onToggle,
      child: MotionContainer(
        motion: motion,
        debugLabel: 'Square',
        width: expanded ? 128 : 64,
        height: 64,
        // A BoxDecoration's color and radius spring; other decorations change
        // at once.
        decoration: BoxDecoration(
          color: expanded ? colors.foreground : colors.accent,
          borderRadius: .circular(expanded ? radii.container : radii.item),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.motion, required this.open});

  final Motion motion;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return MotionSize(
      motion: motion,
      debugLabel: 'Paragraph size',
      alignment: .topCenter,
      child: Text(
        open
            ? 'MotionSize springs to its child\'s size. When its '
                  'constraints change, it follows at once, so a resized '
                  'window never lags.'
            : 'MotionSize springs to its child\'s size.',
        textAlign: TextAlign.center,
        style: text.muted.body,
      ),
    );
  }
}
