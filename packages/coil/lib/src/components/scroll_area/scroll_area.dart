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
/// [CoilScrollArea.motions] or [CoilThemeData.trackMotions].
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

/// A scrolling region with coil's scrollbar, edge fades and platform
/// physics.
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

  /// Gives [child], a scrollable driven by [controller], coil's scroll
  /// behavior, fades and keyboard scrolling.
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

  /// Per-track motions, keyed by [CoilScrollAreaTrack].
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

  /// Scrolls for [event] when the viewport itself has focus. Keys from a
  /// focused descendant pass on to it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (!_controller.hasClients) return KeyEventResult.ignored;
    final line = _style(context).lineStep!;
    final position = _controller.position;
    final from = CoilScrollSpring.targetOf(_controller);
    final page = math.max(position.viewportDimension - line, line);
    final vertical = widget.axis == Axis.vertical;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final back = vertical
        ? LogicalKeyboardKey.arrowUp
        : (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
    final forward = vertical
        ? LogicalKeyboardKey.arrowDown
        : (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
    final target = switch (key) {
      _ when key == back => from - line,
      _ when key == forward => from + line,
      LogicalKeyboardKey.pageUp => from - page,
      LogicalKeyboardKey.pageDown => from + page,
      LogicalKeyboardKey.home => position.minScrollExtent,
      LogicalKeyboardKey.end => position.maxScrollExtent,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    CoilScrollSpring.scrollTo(
      _controller,
      target,
      CoilTheme.trackMotionOf(
        context,
        CoilScrollAreaTrack.scroll,
        instance: widget.motions,
        token: CoilTheme.motionOf(context, override: widget.motion).standard,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final behavior = CoilScrollBehavior(
      tier: CoilTheme.tierOf(context),
      scrollbar: widget.scrollbar == CoilScrollbarVisibility.auto,
      look: style.scrollbarLook,
    );

    final scrollable = widget._wrapsScrollable
        ? widget.child
        : SingleChildScrollView(
            controller: _controller,
            scrollDirection: widget.axis,
            padding: widget.padding,
            child: widget.child,
          );

    Widget area = ScrollConfiguration(
      behavior: behavior,
      child: CoilEdgeFade(
        axis: widget.axis,
        extent: style.fadeExtent!,
        enabled: widget.edgeFades == CoilEdgeFades.auto,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _onMetrics(n.metrics, n.depth),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onMetrics(n.metrics, n.depth),
            child: PrimaryScrollController(
              controller: _controller,
              child: scrollable,
            ),
          ),
        ),
      ),
    );
    if (widget.keyboard) {
      final focusable = _scrolls;
      area = Focus(
        focusNode: _focusNode,
        canRequestFocus: focusable,
        skipTraversal: !focusable,
        onKeyEvent: _onKey,
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
              offset: -(1 + CoilTheme.of(context).focusRingWidth),
              child: child!,
            ),
            child: area,
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
