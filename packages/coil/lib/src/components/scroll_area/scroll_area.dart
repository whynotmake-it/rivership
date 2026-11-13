// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/scroll_area/scroll_area_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';

/// Which edges of a [CoilScrollArea] fade.
enum CoilEdgeFades {
  /// Edges with more content fade out over the style's `fadeExtent`.
  auto,

  /// No fades.
  none,
}

/// A scrolling region with coil's scroll behavior: platform physics,
/// Android's stretch overscroll, a thin pointer scrollbar that widens on
/// hover, a touch overlay bar, and edge fades where there's more content.
///
/// When its content overflows, the viewport is a tab stop: the arrow keys
/// scroll by a line, Page Up/Down by a page, Home/End to the ends, and a
/// keyboard focus ring sits 1 px inside it. Keyboard scrolls spring on the
/// theme's `standard` token (instant under reduced motion).
///
/// [CoilScrollArea] scrolls [child] itself. Use [CoilScrollArea.scrollable]
/// to give an existing scrollable (a `ListView`) the same behavior; pass it
/// the same [controller].
class CoilScrollArea extends StatefulWidget {
  /// Scrolls [child] along [axis].
  const CoilScrollArea({
    required this.child,
    super.key,
    this.controller,
    this.axis = Axis.vertical,
    this.padding,
    this.edgeFades = CoilEdgeFades.auto,
    this.scrollbar = true,
    this.focusNode,
    this.semanticLabel,
    this.style,
    this.motion,
  }) : _wrapsScrollable = false;

  /// Gives [child], a scrollable driven by [controller], coil's scroll
  /// behavior, fades and keyboard scrolling.
  const CoilScrollArea.scrollable({
    required this.child,
    required ScrollController this.controller,
    super.key,
    this.axis = Axis.vertical,
    this.edgeFades = CoilEdgeFades.auto,
    this.scrollbar = true,
    this.focusNode,
    this.semanticLabel,
    this.style,
    this.motion,
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
  final bool scrollbar;

  /// The viewport's focus node (it takes focus only when it scrolls).
  final FocusNode? focusNode;

  /// A name for the scrolling region.
  final String? semanticLabel;

  /// Overrides for the look, on top of the theme's [CoilScrollAreaStyle].
  final CoilScrollAreaStyle? style;

  /// Overrides the theme's motion tokens for keyboard scrolling.
  final CoilMotion? motion;

  final bool _wrapsScrollable;

  @override
  State<CoilScrollArea> createState() => _CoilScrollAreaState();
}

class _CoilScrollAreaState extends State<CoilScrollArea>
    with SingleTickerProviderStateMixin {
  ScrollController? _ownController;
  ScrollController get _controller =>
      widget.controller ?? (_ownController ??= ScrollController());

  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilScrollArea'));

  /// Drives keyboard scrolls on a spring.
  late final _spring = CoilScrollSpring(
    vsync: this,
    debugLabel: 'CoilScrollArea.keyboard',
  );

  bool _scrolls = false;
  bool _focused = false;

  @override
  void dispose() {
    _spring.dispose();
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics, int depth) {
    if (depth != 0) return false;
    final scrolls = metrics.maxScrollExtent > metrics.minScrollExtent;
    if (scrolls != _scrolls) setState(() => _scrolls = scrolls);
    return false;
  }

  bool _onScroll(ScrollNotification n) {
    // A user drag takes over from a keyboard scroll.
    if (n.depth == 0 && n is ScrollStartNotification && n.dragDetails != null) {
      _spring.stop();
    }
    return _onMetrics(n.metrics, n.depth);
  }

  void _scrollBy(double Function(ScrollPosition position) target) {
    if (!_controller.hasClients) return;
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    _spring.scrollTo(
      _controller,
      target(_controller.position),
      motion.standard,
    );
  }

  /// One arrow-key step: about three lines of body text.
  static const _line = 60.0;

  Map<ShortcutActivator, VoidCallback> get _bindings {
    final vertical = widget.axis == Axis.vertical;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    double page(ScrollPosition p) =>
        math.max(p.viewportDimension - _line, _line);
    final back = vertical
        ? LogicalKeyboardKey.arrowUp
        : (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
    final forward = vertical
        ? LogicalKeyboardKey.arrowDown
        : (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
    return {
      SingleActivator(back): () => _scrollBy((p) => _target(p) - _line),
      SingleActivator(forward): () => _scrollBy((p) => _target(p) + _line),
      const SingleActivator(LogicalKeyboardKey.pageUp): () =>
          _scrollBy((p) => _target(p) - page(p)),
      const SingleActivator(LogicalKeyboardKey.pageDown): () =>
          _scrollBy((p) => _target(p) + page(p)),
      const SingleActivator(LogicalKeyboardKey.home): () =>
          _scrollBy((p) => p.minScrollExtent),
      const SingleActivator(LogicalKeyboardKey.end): () =>
          _scrollBy((p) => p.maxScrollExtent),
    };
  }

  /// Where the scroll is headed, so repeated keys add up.
  double _target(ScrollPosition position) => _spring.targetOf(_controller);

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final style = CoilScrollAreaStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context))
        .merge(widget.style);
    final behavior = CoilScrollBehavior(
      tier: CoilTheme.tierOf(context),
      scrollbar: widget.scrollbar,
      look: CoilScrollbarLook(
        color: style.thumb!,
        hoverColor: style.thumbHovered!,
        dragColor: style.thumbDragged!,
        thickness: style.thickness!,
        hoverThickness: style.hoverThickness!,
      ),
    );

    final scrollable = widget._wrapsScrollable
        ? widget.child
        : SingleChildScrollView(
            controller: _controller,
            scrollDirection: widget.axis,
            padding: widget.padding,
            child: widget.child,
          );

    return MotorInspectionScope(
      group: 'CoilScrollArea',
      child: Semantics(
        label: widget.semanticLabel,
        container: widget.semanticLabel != null,
        child: CallbackShortcuts(
          bindings: _scrolls ? _bindings : const {},
          child: Focus(
            focusNode: _focusNode,
            canRequestFocus: _scrolls,
            skipTraversal: !_scrolls,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: ListenableBuilder(
              listenable: CoilInputModality.instance,
              builder: (context, child) => CoilFocusRing(
                visible:
                    _focused &&
                    CoilInputModality.instance.value == CoilModality.keyboard,
                borderRadius: BorderRadius.circular(
                  CoilTheme.radiiOf(context).item,
                ),
                // Inset by 1, inside the clipping viewport.
                offset: -(1 + theme.focusRingWidth),
                child: child!,
              ),
              child: ScrollConfiguration(
                behavior: behavior,
                child: CoilEdgeFade(
                  axis: widget.axis,
                  extent: style.fadeExtent!,
                  enabled: widget.edgeFades == CoilEdgeFades.auto,
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (n) => _onMetrics(n.metrics, n.depth),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: PrimaryScrollController(
                        controller: _controller,
                        child: scrollable,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
