// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/thinking/thinking_indicator_style.dart';
import 'package:coil/src/components/thinking/thinking_roll.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// A status line for work in progress: an optional glyph and a word that
/// changes every 4 seconds.
///
/// The cycle pauses while tickers are muted, for example in a route that is
/// covered.
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
    this.leading,
    this.size,
    this.motion,
    this.style,
  });

  /// The words to cycle through, starting with the first, usually [Text]s.
  ///
  /// Needs at least one. Screen readers hear the current one.
  ///
  /// Words are followed by position, so a parent may rebuild them every
  /// frame and repeat a word. A list of another length takes over at the
  /// next change, from its first word.
  final List<Widget> words;

  /// An optional glyph before the words, styled by [IconTheme] in the
  /// muted color.
  final Widget? leading;

  /// Pins the indicator to one size step.
  ///
  /// Null follows [CoilAdaptiveScope].
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

  /// The shown word's position in [CoilThinkingIndicator.words], or -1
  /// when it is no longer in the list (the next change starts over).
  int _index = 0;

  /// The shown word.
  ///
  /// It can be a word [CoilThinkingIndicator.words] no longer has, until the
  /// next change.
  late Widget _word = widget.words.first;

  /// Counts word changes, so a word that repeats still rolls.
  int _turn = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.words.isNotEmpty, 'words needs at least one word');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The cycle runs only while tickers do, so a hidden tab or a covered
    // route doesn't keep rebuilding.
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled && _timer == null) {
      _timer = Timer.periodic(CoilThinkingIndicator.interval, (_) => _next());
    } else if (!enabled) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(CoilThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.words.isNotEmpty, 'words needs at least one word');
    final words = widget.words;
    if (identical(words, oldWidget.words) || _index < 0) return;
    if (words.length == oldWidget.words.length) {
      // The same list rebuilt (a parent passing new `Text`s each build):
      // the word keeps its place and shows the new widget in place.
      _word = words[_index];
    } else {
      // Another list: the shown word stays until the timer, which then
      // starts from the first word, so announcements keep their pace.
      _index = -1;
    }
  }

  // The word only changes on the timer, even when [words] changes, which
  // keeps announcements at most one per interval.
  void _next() {
    final words = widget.words;
    final index = (_index + 1) % words.length;
    if (index == _index && identical(words[index], _word)) return;
    setState(() {
      _index = index;
      _word = words[index];
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

    final words = Stack(
      children: [
        // Invisible copies of every word reserve the longest one's width.
        for (final word in {...widget.words, _word})
          ExcludeSemantics(
            child: Visibility.maintain(visible: false, child: word),
          ),
        Positioned.fill(
          child: ClipRect(
            child: MotionSwitcher(
              motion: reduced ? motion.fade : motion.standard,
              exitMotion: reduced ? motion.fadeExit : motion.standardExit,
              debugLabel: 'CoilThinkingIndicator.word',
              transitionBuilder: (child, presence) => ThinkingRoll(
                presence: presence,
                rise: !reduced,
                child: child,
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(
                key: ValueKey(_turn),
                child: _word,
              ),
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
        // The current word names the region; the glyph, the hidden copies
        // and a leaving word stay out.
        child: DefaultTextStyle(
          style: style.textStyle!,
          maxLines: 1,
          softWrap: false,
          // A word wider than the room ends in an ellipsis.
          overflow: TextOverflow.ellipsis,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoilPresentSlot(
                axis: Axis.horizontal,
                gap: metrics.gap,
                gapSide: CoilPresentSlotGap.after,
                motion: widget.motion,
                debugLabel: 'CoilThinkingIndicator.leading',
                child: widget.leading == null
                    ? null
                    : ExcludeSemantics(
                        child: IconTheme(
                          data: IconThemeData(
                            size: style.glyphSize,
                            color: style.glyphColor,
                            applyTextScaling: true,
                          ),
                          child: widget.leading!,
                        ),
                      ),
              ),
              Flexible(child: words),
            ],
          ),
        ),
      ),
    );
  }
}
