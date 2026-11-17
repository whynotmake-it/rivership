// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/scroll_area/scroll_area_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilScrollArea]. Use them as keys of
/// [CoilScrollArea.motions] or [CoilScrollAreaStyle.motions].
final class CoilScrollAreaTrack<T extends Object> extends Track<T> {
  CoilScrollAreaTrack._(super.converter, {required String super.debugLabel});

  /// A keyboard scroll. Default motion: `standard`.
  static final scroll = CoilScrollAreaTrack<double>._(
    .single,
    debugLabel: 'CoilScrollArea.scroll',
  );
}

/// Whether a [CoilScrollArea] draws a scrollbar.
enum CoilScrollbarVisibility {
  /// coil's scrollbar for the tier: on pointer it shows while scrolling or
  /// hovered; on touch it is a thin bar while scrolling.
  auto,

  /// No scrollbar.
  none,
}

/// Which edges of a [CoilScrollArea] fade.
enum CoilEdgeFades {
  /// Edges with more content fade out over the style's `fadeExtent`.
  auto,

  /// No fades.
  none,
}

/// A scrolling region with coil's scrollbar and edge fades.
///
/// It scrolls the way the app does: physics, overscroll and which pointers
/// drag the content come from the ambient [ScrollBehavior] (the
/// platform's, unless the app sets its own with [ScrollConfiguration]).
/// coil only draws its own scrollbar in place of the behavior's.
///
/// When the content overflows, the viewport becomes a tab stop. While it
/// has focus, the arrow keys scroll a line, Page Up and Page Down a page,
/// and Home and End go to the ends. Keys pressed in a focused descendant,
/// such as a text field, stay with it.
///
/// Use [CoilScrollArea.scrollable] to wrap a list you already have, and pass
/// both the same [controller].
class CoilScrollArea extends StatefulWidget {
  /// Scrolls [child] along [axis].
  const CoilScrollArea({
    required this.child,
    super.key,
    this.controller,
    this.axis = Axis.vertical,
    this.padding,
    this.edgeFades = CoilEdgeFades.auto,
    this.scrollbar = CoilScrollbarVisibility.auto,
    this.keyboard = true,
    this.focusNode,
    this.semanticLabel,
    this.style,
    this.motion,
    this.motions,
  }) : _wrapsScrollable = false;

  /// Gives [child], a scrollable driven by [controller], coil's scrollbar,
  /// fades and keyboard scrolling.
  const CoilScrollArea.scrollable({
    required this.child,
    required ScrollController this.controller,
    super.key,
    this.axis = Axis.vertical,
    this.edgeFades = CoilEdgeFades.auto,
    this.scrollbar = CoilScrollbarVisibility.auto,
    this.keyboard = true,
    this.focusNode,
    this.semanticLabel,
    this.style,
    this.motion,
    this.motions,
  }) : padding = null,
       _wrapsScrollable = true;

  /// The content, or the scrollable for [CoilScrollArea.scrollable].
  final Widget child;

  /// The scroll controller; one is created if null.
  final ScrollController? controller;

  /// The scroll axis.
  final Axis axis;

  /// Padding inside the scroll view.
  final EdgeInsetsGeometry? padding;

  /// Which edges fade.
  final CoilEdgeFades edgeFades;

  /// Whether to draw a scrollbar.
  final CoilScrollbarVisibility scrollbar;

  /// Whether the area is a tab stop that scrolls with the keys. Turn it off
  /// when the content is the tab stop and handles the keys itself, as a
  /// table does.
  final bool keyboard;

  /// The viewport's focus node (it takes focus only when it scrolls).
  final FocusNode? focusNode;

  /// A name for the scrolling region.
  final String? semanticLabel;

  /// Overrides for the look, on top of the theme's [CoilScrollAreaStyle].
  final CoilScrollAreaStyle? style;

  /// Overrides the theme's motion tokens for keyboard scrolling.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilScrollAreaTrack]. They win over the
  /// style's [CoilScrollAreaStyle.motions] and the tokens.
  final Map<CoilScrollAreaTrack<Object>, Motion>? motions;

  final bool _wrapsScrollable;

  @override
  State<CoilScrollArea> createState() => _CoilScrollAreaState();
}

class _CoilScrollAreaState extends State<CoilScrollArea> {
  ScrollController? _ownController;
  ScrollController get _controller =>
      widget.controller ?? (_ownController ??= ScrollController());

  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilScrollArea'));

  final _states = WidgetStatesController();
  bool _scrolls = false;

  @override
  void dispose() {
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _states.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics, int depth) {
    if (depth != 0) return false;
    final scrolls = metrics.maxScrollExtent > metrics.minScrollExtent;
    if (scrolls != _scrolls) setState(() => _scrolls = scrolls);
    return false;
  }

  CoilScrollAreaStyle _style(BuildContext context) =>
      CoilScrollAreaStyle.fallback(
            CoilTheme.of(context),
            CoilTheme.metricsOf(context),
          )
          .merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context))
          .merge(widget.style);

  /// Whether a key scrolls now: only while the viewport itself has focus.
  /// Keys from a focused descendant pass on to it.
  bool get _canScroll => _focusNode.hasPrimaryFocus && _controller.hasClients;

  void _scroll(_ScrollStep step) {
    final style = _style(context);
    final line = style.lineStep!;
    final position = _controller.position;
    final from = CoilScrollSpring.targetOf(_controller);
    final page = math.max(position.viewportDimension - line, line);
    final target = switch (step) {
      .lineBack => from - line,
      .lineForward => from + line,
      .pageBack => from - page,
      .pageForward => from + page,
      .start => position.minScrollExtent,
      .end => position.maxScrollExtent,
    };
    CoilScrollSpring.scrollTo(
      _controller,
      target,
      CoilTheme.trackMotionOf(
        context,
        CoilScrollAreaTrack.scroll,
        instance: widget.motions,
        styled: style.motions,
        token: CoilTheme.motionOf(context, override: widget.motion).standard,
      ),
    );
  }

  late final _action = _ScrollAction(this);

  /// The keys: arrows along [CoilScrollArea.axis] (in reading direction),
  /// Page Up and Down, Home and End.
  Map<ShortcutActivator, Intent> _shortcuts(BuildContext context) {
    final axis = widget.axis;
    final vertical = axis == Axis.vertical;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final back = vertical
        ? LogicalKeyboardKey.arrowUp
        : (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
    final forward = vertical
        ? LogicalKeyboardKey.arrowDown
        : (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
    return {
      SingleActivator(back): _ScrollIntent(.lineBack, axis),
      SingleActivator(forward): _ScrollIntent(.lineForward, axis),
      const SingleActivator(LogicalKeyboardKey.pageUp): _ScrollIntent(
        .pageBack,
        axis,
      ),
      const SingleActivator(LogicalKeyboardKey.pageDown): _ScrollIntent(
        .pageForward,
        axis,
      ),
      const SingleActivator(LogicalKeyboardKey.home): _ScrollIntent(
        .start,
        axis,
      ),
      const SingleActivator(LogicalKeyboardKey.end): _ScrollIntent(.end, axis),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    // The app's scroll behavior, as it is here. The area keeps its physics,
    // overscroll and drag devices, and only swaps the scrollbar.
    final ambient = ScrollConfiguration.of(context);

    var scrollable = widget._wrapsScrollable
        ? widget.child
        : SingleChildScrollView(
            controller: _controller,
            scrollDirection: widget.axis,
            padding: widget.padding,
            // Scrollables in the content keep the app's behavior, scrollbar
            // included.
            child: ScrollConfiguration(
              behavior: ambient,
              child: widget.child,
            ),
          );
    if (widget.scrollbar == CoilScrollbarVisibility.auto) {
      scrollable = CoilScrollbar(
        controller: _controller,
        look: style.scrollbarLook,
        tier: CoilTheme.tierOf(context),
        fadeDuration:
            CoilTheme.motionOf(
              context,
              override: widget.motion,
            ).fade.duration ??
            const Duration(milliseconds: 120),
        child: scrollable,
      );
    }

    Widget fade(Widget child) => switch ((widget.edgeFades, style.fadeColor)) {
      (CoilEdgeFades.none, _) => child,
      (_, final Color color) => CoilScrollEdgeFade.solid(
        axis: widget.axis,
        extent: style.fadeExtent!,
        color: color,
        child: child,
      ),
      _ => CoilScrollEdgeFade(
        axis: widget.axis,
        extent: style.fadeExtent!,
        child: child,
      ),
    };

    var area = fade(
      // Whether it scrolls changes only with its extents, which this
      // reports after the frame. A scroll notification can come during
      // layout, when the area can't rebuild.
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: PrimaryScrollController(
          controller: _controller,
          child: scrollable,
        ),
      ),
    );
    if (widget.keyboard) {
      final focusable = _scrolls;
      area = Shortcuts(
        shortcuts: _shortcuts(context),
        child: Actions(
          actions: {_ScrollIntent: _action},
          child: Focus(
            focusNode: _focusNode,
            canRequestFocus: focusable,
            skipTraversal: !focusable,
            child: CoilInteractionDetector(
              states: _states,
              focusNode: _focusNode,
              trackPress: false,
              child: ListenableBuilder(
                listenable: _states,
                builder: (context, child) => CoilFocusRing(
                  visible: _states.value.contains(WidgetState.focused),
                  borderRadius: BorderRadius.circular(
                    CoilTheme.radiiOf(context).item,
                  ),
                  // Inside the clipping viewport.
                  offset: -(1 + CoilTheme.of(context).focusRing.width),
                  child: child!,
                ),
                child: area,
              ),
            ),
          ),
        ),
      );
    }

    return MotorInspectionScope(
      group: 'CoilScrollArea',
      child: Semantics(
        label: widget.semanticLabel,
        container: widget.semanticLabel != null,
        child: area,
      ),
    );
  }
}

/// How far a key scrolls a [CoilScrollArea].
enum _ScrollStep { lineBack, lineForward, pageBack, pageForward, start, end }

/// Scrolls a [CoilScrollArea] by a [_ScrollStep]. Not Flutter's
/// `ScrollIntent`: the app's default action for that one would answer for
/// the area while a field inside it has focus.
///
/// It names its area's [axis]: an arrow an inner area leaves alone, such
/// as Down in a horizontal area, bubbles to an outer area's [Shortcuts],
/// whose lookup starts at the focused inner area again.
class _ScrollIntent extends Intent {
  const _ScrollIntent(this.step, this.axis);

  final _ScrollStep step;

  final Axis axis;
}

class _ScrollAction extends Action<_ScrollIntent> {
  _ScrollAction(this.state);

  final _CoilScrollAreaState state;

  @override
  bool isEnabled(_ScrollIntent intent) =>
      intent.axis == state.widget.axis && state._canScroll;

  @override
  void invoke(_ScrollIntent intent) => state._scroll(intent.step);
}
