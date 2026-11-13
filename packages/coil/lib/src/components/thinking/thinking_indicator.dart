// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/src/components/thinking/thinking_indicator_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A status line for work in progress: an optional glyph and a word that
/// changes every 4 seconds.
///
/// The incoming word rises into place and the outgoing one rises out. The
/// row is as wide as the longest word, so it never shifts what follows.
/// With reduced motion the words crossfade.
///
/// Screen readers hear it as a polite live region that announces the new
/// word, at most once every 4 seconds.
class CoilThinkingIndicator extends StatefulWidget {
  /// Creates a thinking indicator.
  const CoilThinkingIndicator({
    required this.words,
    super.key,
    this.glyph,
    this.size,
    this.motion,
    this.style,
  });

  /// The words to cycle through, starting with the first. Needs at least
  /// one.
  final List<String> words;

  /// An optional glyph before the words, styled by [IconTheme] in the
  /// muted color.
  final Widget? glyph;

  /// Pins the indicator to one size step. Null follows
  /// [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides for this indicator's look, on top of the theme's
  /// [CoilThinkingIndicatorStyle] and the defaults.
  final CoilThinkingIndicatorStyle? style;

  /// How long each word shows.
  static const interval = Duration(seconds: 4);

  @override
  State<CoilThinkingIndicator> createState() => _CoilThinkingIndicatorState();
}

class _CoilThinkingIndicatorState extends State<CoilThinkingIndicator> {
  Timer? _timer;
  late String _word = widget.words.first;

  /// Counts word changes, so a word that repeats still rolls.
  int _turn = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.words.isNotEmpty, 'words needs at least one word');
    _timer = Timer.periodic(CoilThinkingIndicator.interval, (_) => _next());
  }

  // The word only changes on the timer, even when [words] changes, which
  // keeps announcements at most one per interval.
  void _next() {
    final words = widget.words;
    final next = words[(words.indexOf(_word) + 1) % words.length];
    if (next == _word) return;
    setState(() {
      _word = next;
      _turn++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final style = CoilThinkingIndicatorStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilThinkingIndicatorStyle>(context))
        .merge(widget.style);

    Text text(String word, {Key? key}) =>
        Text(word, key: key, maxLines: 1, softWrap: false);

    final words = Stack(
      children: [
        // Invisible copies of every word reserve the longest one's width.
        for (final word in {...widget.words, _word})
          Visibility.maintain(visible: false, child: text(word)),
        Positioned.fill(
          child: ClipRect(
            child: MotionSwitcher(
              motion: reduced ? motion.fade : motion.standard,
              exitMotion: reduced ? motion.fadeExit : motion.standardExit,
              debugLabel: 'CoilThinkingIndicator.word',
              transitionBuilder: (child, presence) =>
                  _Roll(presence: presence, rise: !reduced, child: child),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: text(_word, key: ValueKey(_turn)),
            ),
          ),
        ),
      ],
    );

    return MotorInspectionScope(
      group: 'CoilThinkingIndicator',
      child: Semantics(
        container: true,
        liveRegion: true,
        label: _word,
        child: ExcludeSemantics(
          child: DefaultTextStyle(
            style: style.textStyle!,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: metrics.gap,
              children: [
                if (widget.glyph case final glyph?)
                  IconTheme(
                    data: IconThemeData(
                      size: style.glyphSize,
                      color: style.glyphColor,
                      applyTextScaling: true,
                    ),
                    child: glyph,
                  ),
                words,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades a word with its presence and, when [rise] is on, moves it up: an
/// entering word rises from 80 % of its height below, a leaving one rises
/// 80 % above.
class _Roll extends StatelessWidget {
  const _Roll({
    required this.presence,
    required this.rise,
    required this.child,
  });

  final Animation<double> presence;
  final bool rise;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: presence,
    child: child,
    builder: (context, child) {
      final p = presence.value;
      final leaving = presence.status == AnimationStatus.reverse;
      return FractionalTranslation(
        translation: Offset(0, rise ? (1 - p) * 0.8 * (leaving ? -1 : 1) : 0),
        child: Opacity(opacity: p.clamp(0, 1), child: child),
      );
    },
  );
}
