import 'dart:async';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/scroll.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/shell/turns_playground.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// Jumps across 10,000 messages and counts the rows each jump builds.
class JumpsConcept extends StatefulWidget {
  const JumpsConcept({super.key});

  @override
  State<JumpsConcept> createState() => _JumpsConceptState();
}

const _count = 10000;

class _JumpsConceptState extends State<JumpsConcept> {
  final _controller = TurnScrollController();
  final _code = ValueNotifier("controller.scrollTo('m1');");
  var _animate = true;
  var _built = 0;
  var _counting = false;
  var _frames = 0;
  int? _from;
  int? _target;
  ({int built, int frames, int walked})? _last;

  /// Roughly where the view is, from the rows it last built.
  var _near = _count - 1;

  @override
  void dispose() {
    _controller.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _jump(int? index) async {
    final from = _near;
    _code.value = index == null
        ? 'controller.scrollToBottom(animate: $_animate);'
        : "controller.scrollTo('m$index', animate: $_animate);";
    setState(() {
      _built = 0;
      _frames = 0;
      _counting = true;
      _from = from;
      _target = index ?? _count - 1;
    });
    void countFrame(Duration _) {
      if (!mounted || !_counting) return;
      _frames++;
      WidgetsBinding.instance.addPostFrameCallback(countFrame);
    }

    WidgetsBinding.instance.addPostFrameCallback(countFrame);
    if (index == null) {
      await _controller.scrollToBottom(animate: _animate);
    } else {
      await _controller.scrollTo(index, alignment: 0.3, animate: _animate);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _counting = false;
      _last = (
        built: _built,
        frames: _frames,
        walked: ((_target ?? 0) - from).abs(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    String n(int v) => v.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return ConceptPage(
      routeName: turnsJumpsRouteName,
      lead:
          'A plain sliver list has no map from index to offset: to reach a '
          'row far away it lays out every row in between. TurnScrollView '
          'recenters on the target instead, so a jump builds about a screen '
          'of rows whether it goes 10 messages or 10,000. Animated jumps '
          'that far glide only the last screen.',
      controls: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, label) in const [
            (0, '#0'),
            (2500, '#2,500'),
            (5000, '#5,000'),
            (9000, '#9,000'),
          ])
            CoilButton(
              key: Key('concept.jumps.$index'),
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              onPressed: () => unawaited(_jump(index)),
              child: Text('Jump to $label'),
            ),
          CoilButton(
            key: const Key('concept.jumps.bottom'),
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.arrowDownToLine, size: 14),
            onPressed: () => unawaited(_jump(null)),
            child: const Text('Latest'),
          ),
          SizedBox(
            width: 150,
            child: PlaygroundToggle(
              label: 'Animate',
              value: _animate,
              onChanged: (v) => setState(() => _animate = v),
            ),
          ),
        ],
      ),
      stage: TurnScrollView<Object>(
        controller: _controller,
        itemCount: _count,
        itemId: (i) => i,
        itemSpacing: 4,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        itemBuilder: (context, i) {
          if (_counting) _built++;
          _near = i;
          return _Row(index: i, target: i == _target && !_counting);
        },
      ),
      readout: ConceptStats(
        children: [
          ConceptStat(
            label: 'Rows a plain list would walk',
            value: last == null ? '–' : n(last.walked),
            tone: ConceptTone.bad,
          ),
          ConceptStat(
            label: 'Rows TurnScrollView built',
            value: last == null ? '–' : n(last.built),
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'Frames',
            value: last == null ? '–' : n(last.frames),
          ),
          if (_from case final from?)
            ConceptStat(label: 'From', value: '≈ #${n(from)}'),
        ],
      ),
      code: _code,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.index, required this.target});

  final int index;
  final bool target;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    // Rows differ in height, as real messages do, so offsets can't be
    // computed from the index.
    final lines = 1 + (index * 7919) % 3;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: target ? colors.brandWash : colors.background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: target ? colors.brandMark : colors.border,
            width: target ? 1.5 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text('#$index', style: text.caption.tabular),
            ),
            Expanded(
              child: Text(
                List.filled(lines, 'Message body that takes a line.').join(
                  '\n',
                ),
                style: text.muted.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
