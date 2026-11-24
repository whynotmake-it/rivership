// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/scroll_area/scroll_area_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilScrollArea].
///
/// Use these as keys of [CoilScrollArea.motions] or
/// [CoilScrollAreaStyle.motions].
final class CoilScrollAreaTrack<T extends Object> extends Track<T> {
  CoilScrollAreaTrack._(super.converter, {required String super.debugLabel});

  /// A keyboard scroll.
  ///
  /// Defaults to [CoilMotion.standard].
  static final scroll = CoilScrollAreaTrack<double>._(
    .single,
    debugLabel: 'CoilScrollArea.scroll',
  );
}

/// Whether a [CoilScrollArea] draws a scrollbar.
enum CoilScrollbarVisibility {
  /// Coil's scrollbar for the tier: on pointer it shows while scrolling or
  /// hovered; on touch it is a thin bar while scrolling.
  auto,

  /// No scrollbar.
  none,
}

/// Edge-fade behavior along the scroll axis of a [CoilScrollArea].
enum CoilEdgeFades {
  /// Edges with more content fade out over [CoilScrollAreaStyle.fadeExtent].
  auto,

  /// No fades.
  none,
}

/// Gives a scrollable Coil's scrollbar, edge fades, and keyboard scrolling.
///
/// [child] is the scrollable: a [ListView], [GridView], [CustomScrollView],
/// [SingleChildScrollView] or any other. The area never builds one itself.
///
/// ```dart
/// CoilScrollArea(
///   child: ListView(children: ...),
/// )
/// ```
///
/// Without a [controller], the area provides one through
/// [PrimaryScrollController], on every platform and for [axis], so a child
/// that sets no controller of its own picks it up. With a [controller], pass
/// the same one to the child. In debug mode the area asserts if the child
/// doesn't attach to that controller.
///
/// It scrolls the way the app does: physics, overscroll and which pointers
/// drag the content come from the ambient [ScrollBehavior] (the
/// platform's, unless the app sets its own with [ScrollConfiguration]).
/// Coil only draws its own scrollbar in place of the behavior's.
///
/// The edge fades follow the child's scroll notifications, so they work
/// with any scrollable along [axis].
///
/// When the content overflows, the viewport becomes a tab stop. While it
/// has focus, the arrow keys scroll a line, Page Up and Page Down a page,
/// and Home and End go to the ends. Keys pressed in a focused descendant,
/// such as a text field, stay with it.
class CoilScrollArea extends StatefulWidget {
  /// Gives [child], a scrollable along [axis], Coil's scrollbar, fades, and
  /// keyboard scrolling.
  const CoilScrollArea({
    required this.child,
    super.key,
    this.controller,
    this.axis = Axis.vertical,
    this.edgeFades = CoilEdgeFades.auto,
    this.scrollbar = CoilScrollbarVisibility.auto,
    this.keyboard = true,
    this.focusNode,
    this.semanticLabel,
    this.style,
    this.motion,
    this.motions,
  });

  /// The scrollable.
  ///
  /// Wrap plain content in a [SingleChildScrollView].
  final Widget child;

  /// The controller [child] scrolls with.
  ///
  /// If null, the area provides one through [PrimaryScrollController]; if set,
  /// pass it to [child] too.
  final ScrollController? controller;

  /// The axis [child] scrolls along.
  final Axis axis;

  /// Which edges fade.
  final CoilEdgeFades edgeFades;

  /// Whether to draw a scrollbar.
  final CoilScrollbarVisibility scrollbar;

  /// Whether the area is a tab stop that scrolls with the keys.
  ///
  /// Turn it off when the content is the tab stop and handles the keys itself,
  /// as a table does.
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
  ///
  /// These take precedence over [CoilScrollAreaStyle.motions] and the theme
  /// tokens.
  final Map<CoilScrollAreaTrack<Object>, Motion>? motions;

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
  void initState() {
    super.initState();
    _debugCheckAttached();
  }

  @override
  void didUpdateWidget(CoilScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.axis != oldWidget.axis) {
      _debugCheckAttached();
    }
  }

  /// Asserts, after the frame, that [CoilScrollArea.child] scrolls with
  /// the area's controller.
  void _debugCheckAttached() {
    assert(
      () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _debugAssertAttached();
        });
        return true;
      }(),
      'Schedules the check; never fails.',
    );
  }

  void _debugAssertAttached() {
    final controller = _controller;
    final axis = widget.axis.name;
    final fix = widget.controller == null
        ? 'With no controller given, the area provides one through '
              'PrimaryScrollController. The child must set no controller of '
              'its own and must not set primary: false. If it has its own '
              'controller, pass that controller to the area too.'
        : 'Pass the same controller to the child as to the area.';
    assert(
      controller.hasClients,
      "CoilScrollArea: its child didn't attach to the scroll controller.\n"
      "The child must be a scrollable along the area's axis ($axis), such "
      'as a ListView, GridView, CustomScrollView or SingleChildScrollView, '
      'built in the same frame. Wrap plain content in a '
      'SingleChildScrollView.\n$fix',
    );
    assert(
      controller.positions.every(
        (p) => axisDirectionToAxis(p.axisDirection) == widget.axis,
      ),
      'CoilScrollArea: its child scrolls along a different axis than the '
      "area ($axis). Set CoilScrollArea.axis to the child's scroll "
      'direction.',
    );
  }

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

  /// Whether a key scrolls now: while the viewport itself has focus, or the
  /// viewport of an area nested in it (a key that area leaves alone, such as
  /// Down in a horizontal area, scrolls this one).
  ///
  /// Keys from any other focused descendant, such as a text field, pass on to
  /// it.
  bool get _canScroll {
    if (!_controller.hasClients) return false;
    if (_focusNode.hasPrimaryFocus) return true;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !_focusNode.hasFocus) return false;
    final nested = primary.context
        ?.findAncestorStateOfType<_CoilScrollAreaState>();
    return nested != null && nested != this && nested._focusNode == primary;
  }

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
    _ScrollIntent intent(_ScrollStep step) =>
        vertical ? _VerticalScrollIntent(step) : _HorizontalScrollIntent(step);
    return {
      SingleActivator(back): intent(.lineBack),
      SingleActivator(forward): intent(.lineForward),
      const SingleActivator(LogicalKeyboardKey.pageUp): intent(.pageBack),
      const SingleActivator(LogicalKeyboardKey.pageDown): intent(.pageForward),
      const SingleActivator(LogicalKeyboardKey.home): intent(.start),
      const SingleActivator(LogicalKeyboardKey.end): intent(.end),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    // The app's scroll behavior, as it is here. The area keeps its physics,
    // overscroll and drag devices, and only swaps the scrollbar.
    final ambient = ScrollConfiguration.of(context);

    // A child that sets no controller of its own scrolls with the area's,
    // on every platform (Flutter's own default is mobile only) and along
    // the area's axis. Only that scrollable loses the behavior's bar;
    // scrollables nested in it keep the app's behavior, bar included.
    Widget scrollable = ScrollConfiguration(
      behavior: _AreaScrollBehavior(ambient, _controller),
      child: PrimaryScrollController(
        controller: _controller,
        scrollDirection: widget.axis,
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        child: widget.child,
      ),
    );
    if (widget.scrollbar != CoilScrollbarVisibility.none) {
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
        child: scrollable,
      ),
    );
    if (widget.keyboard) {
      final focusable = _scrolls;
      area = Shortcuts(
        shortcuts: _shortcuts(context),
        child: Actions(
          actions: {
            if (widget.axis == Axis.vertical) _VerticalScrollIntent: _action,
            if (widget.axis == Axis.horizontal)
              _HorizontalScrollIntent: _action,
          },
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

/// The app's [ambient] behavior, without the scrollbar of the one scrollable
/// that scrolls with [controller]: Coil draws that one's, or none.
///
/// Every other scrollable gets the ambient behavior unchanged.
class _AreaScrollBehavior extends ScrollBehavior {
  const _AreaScrollBehavior(this.ambient, this.controller);

  final ScrollBehavior ambient;
  final ScrollController controller;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => details.controller == controller
      ? child
      : ambient.buildScrollbar(context, child, details);

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => ambient.buildOverscrollIndicator(context, child, details);

  @override
  Set<PointerDeviceKind> get dragDevices => ambient.dragDevices;

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      ambient.pointerAxisModifiers;

  @override
  MultitouchDragStrategy getMultitouchDragStrategy(BuildContext context) =>
      ambient.getMultitouchDragStrategy(context);

  @override
  TargetPlatform getPlatform(BuildContext context) =>
      ambient.getPlatform(context);

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      ambient.getScrollPhysics(context);

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ambient.getKeyboardDismissBehavior(context);

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) =>
      ambient.velocityTrackerBuilder(context);

  @override
  bool shouldNotify(_AreaScrollBehavior oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.ambient != ambient;
}

/// How far a key scrolls a [CoilScrollArea].
enum _ScrollStep { lineBack, lineForward, pageBack, pageForward, start, end }

/// Scrolls a [CoilScrollArea] by a [_ScrollStep].
///
/// Not Flutter's [ScrollIntent]: the app's default action for that one would
/// answer for the area while a field inside it has focus.
///
/// Each axis has its own intent type, [_VerticalScrollIntent] and
/// [_HorizontalScrollIntent], and an area handles only its own. Actions are
/// looked up by type from the focused widget, so a key an inner area leaves
/// alone, such as Down in a horizontal area, passes its [Actions] by and
/// reaches an outer vertical area's.
sealed class _ScrollIntent extends Intent {
  const _ScrollIntent(this.step);

  final _ScrollStep step;
}

class _VerticalScrollIntent extends _ScrollIntent {
  const _VerticalScrollIntent(super.step);
}

class _HorizontalScrollIntent extends _ScrollIntent {
  const _HorizontalScrollIntent(super.step);
}

class _ScrollAction extends Action<_ScrollIntent> {
  _ScrollAction(this.state);

  final _CoilScrollAreaState state;

  @override
  bool isEnabled(_ScrollIntent intent) => state._canScroll;

  @override
  void invoke(_ScrollIntent intent) => state._scroll(intent.step);
}
