import 'dart:async';
import 'dart:math' as math;

import 'package:coil/src/foundation/colors.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/intents.dart';
import 'package:coil/src/primitives/screen_radius.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

/// A side of a [CoilDrawer], following the text direction.
enum CoilDrawerEdge {
  /// The leading edge: left in a left-to-right layout.
  start,

  /// The trailing edge: right in a left-to-right layout.
  end,
}

/// How a [CoilDrawer]'s panel meets the content.
enum CoilDrawerReveal {
  /// The panel lies underneath; the content slides aside to reveal it,
  /// rounding its corners like the screen's while it is away from the
  /// edges. The mobile drawer.
  behind,

  /// The panel slides in over the content, which stays put under a scrim.
  over,
}

/// Which drags move a [CoilDrawer].
enum CoilDrawerDrag {
  /// A horizontal drag anywhere on the content opens a panel, and one
  /// anywhere closes the open panel. Horizontal scrollables in the content
  /// keep their drags, and hand them over at their edge.
  anywhere,

  /// Drags only close the open panel; something else, such as a trigger,
  /// opens it.
  close,

  /// Drags do nothing.
  none,
}

/// Below this many logical pixels from rest, the content covers the panel
/// again: its corners square up and the panel goes offstage.
const _restSlop = 0.5;

/// How a [CoilDrawer] looks: the content's corners, fill, shadow and scrim
/// while it is aside, and the panels' fill.
///
/// [CoilDrawerLook.fallback] computes every field from the theme for a
/// reveal; change one with [copyWith]:
///
/// ```dart
/// CoilDrawer(
///   look: CoilDrawerLook.fallback(
///     CoilTheme.of(context),
///     reveal: CoilDrawerReveal.behind,
///   ).copyWith(scrimColor: const Color(0x33000000)),
///   ...
/// )
/// ```
///
/// How the content and panel move as it slides is [CoilDrawerTransition].
@immutable
class CoilDrawerLook {
  /// Creates a drawer look. Prefer [CoilDrawerLook.fallback] and
  /// [copyWith].
  const CoilDrawerLook({
    required this.fallbackCornerRadius,
    required this.scrimColor,
    required this.shadows,
    required this.contentColor,
    this.cornerRadius,
    this.panelColor,
  });

  /// The look for [reveal] from [theme]'s tokens: the screen's corners
  /// (phone radii where unknown), [behindScrim] from behind (a lightening
  /// veil in light, a dim in dark) and the theme's [CoilColors.scrim]
  /// over, shadow step
  /// [edgeShadowLevel] on the content's side, and the page background for
  /// the content and, from behind, the panels.
  factory CoilDrawerLook.fallback(
    CoilThemeData theme, {
    required CoilDrawerReveal reveal,
  }) {
    final colors = theme.colors;
    final behind = reveal == CoilDrawerReveal.behind;
    return CoilDrawerLook(
      fallbackCornerRadius: fallbackCornerRadiusFor(defaultTargetPlatform),
      scrimColor: behind ? behindScrim(colors) : colors.scrim,
      shadows: edgeShadows(colors),
      contentColor: colors.background,
      panelColor: behind ? colors.background : null,
    );
  }

  /// The scrim over the content once a panel revealed from behind is fully
  /// open, for [colors]' brightness.
  ///
  /// In light, a veil of the top of the surface ladder (white in coil's
  /// palette) at [behindVeilAlpha]: the page lightens as it slides away,
  /// the way distant things fade into haze, and its shadow and hairline
  /// keep it apart from the sidebar. In dark, [behindScrimDark]: there a
  /// lighter page would read as raised toward the viewer, so it dims
  /// instead.
  static Color behindScrim(CoilColors colors) =>
      colors.brightness == Brightness.dark
      ? behindScrimDark
      : colors.surfaces.last.withValues(alpha: behindVeilAlpha);

  /// The opacity of [behindScrim]'s lightening veil in light: 35 %. Enough
  /// to push the page back; much more and it looks washed out.
  static const behindVeilAlpha = 0.35;

  /// [behindScrim] in dark: black 15 %. The inverse of the light veil, so
  /// the dark page recedes into the dark instead of lighting up.
  static const behindScrimDark = Color.from(
    alpha: 0.15,
    red: 0,
    green: 0,
    blue: 0,
  );

  /// The shadow step on the content's edge while it is aside: the top of
  /// the ladder, so the page reads as a sheet lifted off the panel.
  static const edgeShadowLevel = 8;

  /// The content's corners while aside on a phone whose screen can't tell
  /// its own radius (the platform query failed or isn't registered): close
  /// to a recent iPhone's and Android phone's.
  static const phoneCornerRadii = {
    TargetPlatform.iOS: 40.0,
    TargetPlatform.android: 24.0,
  };

  /// The default [fallbackCornerRadius] on [platform]: [phoneCornerRadii]
  /// on a phone, square on desktop and the web.
  static BorderRadius fallbackCornerRadiusFor(TargetPlatform platform) =>
      switch (kIsWeb ? null : phoneCornerRadii[platform]) {
        final radius? => BorderRadius.circular(radius),
        null => BorderRadius.zero,
      };

  /// Shadow step [edgeShadowLevel] of [colors], centered on the content
  /// instead of dropped below it. The ladder's drops pull in their sides
  /// (negative spread) to fall under a floating surface; on a page pushed
  /// sideways, the side is the edge that has to show, so the same blurs
  /// and colors spread evenly around it.
  static List<BoxShadow> edgeShadows(CoilColors colors) => [
    for (final shadow in colors.shadow(edgeShadowLevel))
      if (shadow.blurRadius > 0)
        shadow.copyWith(offset: Offset.zero, spreadRadius: 0),
  ];

  /// The content's corners while it is aside, in physical corners. Null
  /// takes the screen's from [CoilScreenRadius], and [fallbackCornerRadius]
  /// where the screen can't tell (web, desktop, a failed query, tests).
  final BorderRadius? cornerRadius;

  /// The content's corners while aside when [cornerRadius] is null and the
  /// screen's radius is unknown.
  final BorderRadius fallbackCornerRadius;

  /// The scrim over the content once a panel is fully open; it fades in
  /// with the slide.
  final Color scrimColor;

  /// The content's shadow while it is aside ([CoilDrawerReveal.behind]),
  /// faded in with the slide. A hairline in the theme's border color fades
  /// in with it.
  final List<BoxShadow> shadows;

  /// The content's fill while it slides ([CoilDrawerReveal.behind]), so
  /// the panel never shows through it.
  final Color contentColor;

  /// The panels' fill. Null over the content is the raised surface's own.
  final Color? panelColor;

  /// Returns a copy with the given fields replaced.
  CoilDrawerLook copyWith({
    BorderRadius? cornerRadius,
    BorderRadius? fallbackCornerRadius,
    Color? scrimColor,
    List<BoxShadow>? shadows,
    Color? contentColor,
    Color? panelColor,
  }) => CoilDrawerLook(
    cornerRadius: cornerRadius ?? this.cornerRadius,
    fallbackCornerRadius: fallbackCornerRadius ?? this.fallbackCornerRadius,
    scrimColor: scrimColor ?? this.scrimColor,
    shadows: shadows ?? this.shadows,
    contentColor: contentColor ?? this.contentColor,
    panelColor: panelColor ?? this.panelColor,
  );

  @override
  bool operator ==(Object other) =>
      other is CoilDrawerLook &&
      other.cornerRadius == cornerRadius &&
      other.fallbackCornerRadius == fallbackCornerRadius &&
      other.scrimColor == scrimColor &&
      listEquals(other.shadows, shadows) &&
      other.contentColor == contentColor &&
      other.panelColor == panelColor;

  @override
  int get hashCode => Object.hash(
    cornerRadius,
    fallbackCornerRadius,
    scrimColor,
    Object.hashAll(shadows),
    contentColor,
    panelColor,
  );
}

/// How a [CoilDrawer]'s content and panel move with the slide, from
/// behind ([CoilDrawerReveal.behind]): the content may shrink away, and
/// the panel emerges from under it, fading and growing in. Each follows
/// the slide, so it tracks a drag.
@immutable
class CoilDrawerTransition {
  /// Creates a drawer transition; the defaults are coil's.
  const CoilDrawerTransition({
    this.scale = 1,
    this.panelScale = 0.95,
    this.panelOpacity = 0.4,
  }) : assert(scale > 0 && scale <= 1, 'scale shrinks the content, 0 to 1'),
       assert(
         panelScale > 0 && panelScale <= 1,
         'panelScale grows the panel in, 0 to 1',
       ),
       assert(
         panelOpacity >= 0 && panelOpacity <= 1,
         'panelOpacity is an opacity, 0 to 1',
       );

  /// How small the content gets once a panel is fully open, 1 for not at
  /// all. It shrinks toward the open panel's far edge, so the panel stays
  /// fully revealed; 0.94 is a subtle depth cue.
  final double scale;

  /// How big the panel's content starts as the content begins to uncover
  /// it; it grows to full size with the slide, from the edge the content
  /// leaves, so it seems to emerge from under it. 1 for no growth. Not
  /// under reduced motion.
  final double panelScale;

  /// How opaque the panel's content is as the content begins to uncover
  /// it; it fades to fully opaque with the slide, so the panel is already
  /// partly there as the content starts to move. 1 for no fade.
  final double panelOpacity;

  @override
  bool operator ==(Object other) =>
      other is CoilDrawerTransition &&
      other.scale == scale &&
      other.panelScale == panelScale &&
      other.panelOpacity == panelOpacity;

  @override
  int get hashCode => Object.hash(scale, panelScale, panelOpacity);
}

/// Shows [child] with a panel on either side, [start] and [end], one of
/// which is [open] at a time.
///
/// With [CoilDrawerReveal.behind] (the default), the panels lie underneath
/// and [child] slides aside to reveal one, taking the device's screen
/// corner radius while it is away from the edges (from [CoilScreenRadius]
/// unless [look] pins one) and squaring up again the moment it covers the
/// panels. As it slides, the panel emerges under it ([transition]), and a
/// veil over the content (lightening in light, dimming in dark; see
/// [CoilDrawerLook.behindScrim]), a shadow and a hairline on its edge
/// follow the drag.
/// With [CoilDrawerReveal.over], the panel slides in over [child] under a
/// scrim.
///
/// Unlike a route, the panels stay descendants of this widget: they show
/// the owner's current state and rebuild with it, the way Flutter's
/// `Scaffold` keeps its drawer. While a panel is open:
///
/// * pressing the content (or the scrim) calls [onOpenChanged] with null,
///   and so do Escape, system back and dragging the panel closed (a fling
///   faster than [flingVelocity] decides by its direction, a slow release
///   by how far it moved);
/// * focus moves into the panel, and returns to where it was on close;
/// * screen readers reach only the panel, a route named by its semantic
///   label, and the content's dismiss action.
///
/// [drag] decides which drags move it. Drags are read with a
/// `ScrollDragDetector`, so a horizontal scrollable inside [child] keeps
/// its drags and hands over to the drawer only when a drag starts at its
/// edge. Once such a drag moves the drawer, the drawer keeps it both ways
/// until it is back where the drag found it, so dragging back follows the
/// finger, and only then does the scrollable scroll again. Drawers nest:
/// a drag the inner drawer can't use (say, toward a side it has no panel
/// on) moves the outer one, and opening one closes
/// the others, so an inner `end` drawer and an outer `start` drawer behave
/// as one drawer with two sides.
///
/// It slides open on the `standard` token and closed on `standardExit`,
/// of [motion] or the theme's (reduced motion makes both instant); a drag
/// follows the finger and its release velocity carries into the spring.
/// [width] is the panels' width, [widthFraction] of this widget's width
/// when null, at most [maxWidth].
class CoilDrawer extends StatefulWidget {
  /// Creates a drawer host.
  const CoilDrawer({
    required this.open,
    required this.onOpenChanged,
    required this.child,
    super.key,
    this.start,
    this.end,
    this.reveal = CoilDrawerReveal.behind,
    this.drag,
    this.width,
    this.startSemanticLabel,
    this.endSemanticLabel,
    this.look,
    this.transition = const CoilDrawerTransition(),
    this.motion,
  });

  /// The widest a panel gets when [width] is null.
  static const maxWidth = 320.0;

  /// The share of the drawer's width a panel takes when [width] is null,
  /// up to [maxWidth].
  static const widthFraction = 0.85;

  /// How fast a release has to be to count as a fling, in logical pixels
  /// per second. A fling decides by its direction; a slower release by how
  /// far the drag moved.
  static const flingVelocity = 400.0;

  /// The open panel, or null when [child] covers both.
  final CoilDrawerEdge? open;

  /// Called when the user opens or closes a panel (null: closed). Set
  /// [open] to the new value; a drawer whose owner keeps [open] as it was
  /// goes back to it.
  final ValueChanged<CoilDrawerEdge?> onOpenChanged;

  /// The content.
  final Widget child;

  /// The panel on the leading side, if any.
  final Widget? start;

  /// The panel on the trailing side, if any.
  final Widget? end;

  /// Whether the panels lie under the content or slide over it.
  final CoilDrawerReveal reveal;

  /// Which drags move the drawer.
  ///
  /// Null decides by the input tier: on touch, drags anywhere open and
  /// close it, except that where the enclosing route can be swiped back
  /// (iOS and macOS, not the first route) the [start] panel only closes by
  /// drag, leaving that swipe to the route. On the pointer tier, drags only
  /// close it.
  final CoilDrawerDrag? drag;

  /// The panels' width. Null is [widthFraction] of this widget's width, at
  /// most [maxWidth].
  final double? width;

  /// The [start] panel's name for screen readers.
  final String? startSemanticLabel;

  /// The [end] panel's name for screen readers.
  final String? endSemanticLabel;

  /// The content's corners, fill, shadow and scrim, and the panels' fill.
  /// Null is [CoilDrawerLook.fallback] for [reveal] from the theme.
  final CoilDrawerLook? look;

  /// How the content and panel move with the slide from behind. Only with
  /// [CoilDrawerReveal.behind].
  final CoilDrawerTransition transition;

  /// Overrides the theme's motion tokens: the slide opens on `standard`
  /// and closes on `standardExit`. Reduced motion still applies.
  final CoilMotion? motion;

  @override
  State<CoilDrawer> createState() => _CoilDrawerState();
}

class _CoilDrawerState extends State<CoilDrawer>
    with SingleTickerProviderStateMixin {
  /// Where the content is: 0 covers both panels, 1 shows [CoilDrawer.start]
  /// and -1 [CoilDrawer.end], in fractions of the panel width.
  late final _position =
      SingleMotionController(
          motion: const Motion.instant(),
          vsync: this,
          initialValue: _targetOf(widget.open),
          velocityTracking: const VelocityTracking.off(),
          debugLabel: 'CoilDrawer.position',
        )
        ..addStatusListener(_onStatus)
        ..addListener(_updateHold);

  final _startScope = FocusScopeNode(debugLabel: 'CoilDrawer.start');
  final _endScope = FocusScopeNode(debugLabel: 'CoilDrawer.end');

  /// Keep the content and the panels (and their state: scroll positions,
  /// text fields) when [CoilDrawer.reveal] changes the frame around them.
  final _contentKey = GlobalKey(debugLabel: 'CoilDrawer.content');
  final _startKey = GlobalKey(debugLabel: 'CoilDrawer.start');
  final _endKey = GlobalKey(debugLabel: 'CoilDrawer.end');

  /// Where [_position] is heading.
  late double _target;

  LocalHistoryEntry? _entry;
  FocusNode? _focusBefore;

  /// The look at the last build.
  late CoilDrawerLook _look;

  /// The panel width at the last layout.
  double _panelWidth = 320;

  /// The enclosing drawer, which takes the drags this one can't use.
  _CoilDrawerState? _parent;
  final _children = <_CoilDrawerState>{};

  /// Who moves with the current drag, once its first move decided.
  _CoilDrawerState? _dragOwner;
  bool _dragDecided = false;

  /// Whether a drag is moving this drawer.
  bool _dragging = false;

  /// The side the current drag started on: 1 start, -1 end, 0 closed.
  double _dragSide = 0;

  /// Where the current drag found the drawer: the position it hands the
  /// drag back to a scrollable at.
  double _dragOrigin = 0;

  /// Whether a drag has moved this drawer away from [_dragOrigin]; while it
  /// has, the drawer keeps the drag in both directions
  /// ([ScrollDragMode.dragFirst]).
  bool _holdsDrag = false;

  /// Whether the drag this drawer's detector reads came out of a
  /// scrollable, and whether the drag moving this drawer did. Only those
  /// need holding: a drag that started outside any scrollable never hands
  /// over to one.
  bool _dragFromScroll = false;
  bool _holdingScroll = false;

  static double _targetOf(CoilDrawerEdge? edge) => switch (edge) {
    CoilDrawerEdge.start => 1.0,
    CoilDrawerEdge.end => -1.0,
    null => 0.0,
  };

  @override
  void initState() {
    super.initState();
    _target = _targetOf(widget.open);
    if (widget.open != null) _schedule(_opened);
    // The screen's radius arrives once, asynchronously; ask early so it is
    // there by the first slide.
    CoilScreenRadius.listenable.addListener(_onScreenRadius);
    if (widget.reveal == CoilDrawerReveal.behind &&
        widget.look?.cornerRadius == null) {
      unawaited(CoilScreenRadius.resolve());
    }
  }

  void _onScreenRadius() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context
        .getInheritedWidgetOfExactType<_CoilDrawerScope>()
        ?.state;
    if (parent != _parent) {
      _parent?._children.remove(this);
      _parent = parent?.._children.add(this);
    }
  }

  @override
  void didUpdateWidget(CoilDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    // A drag that decided this already springs there with its velocity.
    final target = _targetOf(widget.open);
    if (!_dragging && target != _target) _animateTo(target);
    if (oldWidget.open != null) _closed();
    if (widget.open != null) _schedule(_opened);
  }

  @override
  void dispose() {
    CoilScreenRadius.listenable.removeListener(_onScreenRadius);
    _parent?._children.remove(this);
    final entry = _entry;
    _entry = null;
    entry?.remove();
    _position.dispose();
    _startScope.dispose();
    _endScope.dispose();
    super.dispose();
  }

  void _schedule(VoidCallback callback) =>
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) callback();
      });

  // Opening and closing ---------------------------------------------------

  /// Runs after a frame with [CoilDrawer.open] set: every other drawer in
  /// the nest closes, the panel takes focus, and back closes it.
  void _opened() {
    final open = widget.open;
    if (open == null) return;
    var root = this;
    while (root._parent != null) {
      root = root._parent!;
    }
    final (:closedAny, :focus) = root._closeAllBut(this);
    final scope = open == CoilDrawerEdge.start ? _startScope : _endScope;
    if (!scope.hasFocus) {
      if (closedAny) {
        // Focus is in the drawer that just closed: return to where that
        // one would have.
        _focusBefore ??= focus;
      } else if (_focusBefore == null &&
          !_startScope.hasFocus &&
          !_endScope.hasFocus) {
        // Not when switching sides: focus is in the other panel then, and
        // the node to return to is already kept.
        _focusBefore = FocusManager.instance.primaryFocus;
      }
      scope.requestFocus();
    }
    if (_entry == null) {
      if (ModalRoute.of(context) case final route?) {
        route.addLocalHistoryEntry(
          _entry = LocalHistoryEntry(onRemove: _onEntryRemoved),
        );
      }
    }
  }

  /// Closes every open drawer from here down except [keep], and takes the
  /// focus the first of them would have returned to, so [keep] returns it
  /// instead.
  ({bool closedAny, FocusNode? focus}) _closeAllBut(_CoilDrawerState keep) {
    var closedAny = false;
    FocusNode? focus;
    if (this != keep && widget.open != null) {
      closedAny = true;
      focus = _focusBefore;
      _focusBefore = null;
      widget.onOpenChanged(null);
    }
    for (final child in _children.toList()) {
      final closed = child._closeAllBut(keep);
      closedAny |= closed.closedAny;
      focus ??= closed.focus;
    }
    return (closedAny: closedAny, focus: focus);
  }

  void _closed() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    // Switching to the other side keeps the node to return to for the
    // final close.
    if (widget.open != null) return;
    final previous = _focusBefore;
    _focusBefore = null;
    // After the frame that lets the content take focus again.
    _schedule(() {
      if (widget.open != null) {
        // Reopened before the frame ended.
        _focusBefore ??= previous;
        return;
      }
      if (previous != null && previous.context != null) {
        previous.requestFocus();
      }
    });
  }

  void _onEntryRemoved() {
    // Removed by back, not by [_closed].
    if (_entry == null) return;
    _entry = null;
    widget.onOpenChanged(null);
  }

  void _close() {
    if (widget.open != null) widget.onOpenChanged(null);
  }

  /// Escape in an open panel closes it, unless the app handles
  /// [CoilDismissIntent] above the drawer.
  late final _dismiss = CoilDefaultAction<CoilDismissIntent>(
    context: context,
    onInvoke: (_) => _close(),
  );

  Motion _motionToward(double target) {
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    return target == 0 ? tokens.standardExit : tokens.standard;
  }

  void _animateTo(double target, {double? velocity}) {
    _target = target;
    _position
      ..motion = _motionToward(target)
      ..animateTo(target, withVelocity: velocity);
  }

  void _onStatus(AnimationStatus status) {
    // Settled: the panels go offstage and the corners square up.
    if (!status.isAnimating && mounted) setState(() {});
  }

  // Drags -----------------------------------------------------------------

  bool get _startIsLeft => Directionality.of(context) == TextDirection.ltr;

  CoilDrawerDrag _dragFor(CoilDrawerEdge edge) {
    if (widget.drag case final drag?) return drag;
    if (CoilTheme.tierOf(context) == CoilTier.pointer) {
      return CoilDrawerDrag.close;
    }
    if (edge == CoilDrawerEdge.start && _routeSwipesBack) {
      return CoilDrawerDrag.close;
    }
    return CoilDrawerDrag.anywhere;
  }

  /// Whether the enclosing route pops with a swipe from the leading edge,
  /// the same way a drag opens the start panel.
  bool get _routeSwipesBack {
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return apple && !(ModalRoute.of(context)?.isFirst ?? true);
  }

  Widget? _panel(CoilDrawerEdge edge) =>
      edge == CoilDrawerEdge.start ? widget.start : widget.end;

  /// The edge a drag moving right (`physicalRight`) or left opens from
  /// rest.
  CoilDrawerEdge _edgeOpenedBy({required bool physicalRight}) =>
      physicalRight == _startIsLeft ? CoilDrawerEdge.start : CoilDrawerEdge.end;

  /// Whether this drawer moves with a drag in that physical direction now.
  bool _uses({required bool physicalRight}) {
    final position = _position.value;
    if (position.abs() * _panelWidth > _restSlop || widget.open != null) {
      final edge = position > 0 || widget.open == CoilDrawerEdge.start
          ? CoilDrawerEdge.start
          : CoilDrawerEdge.end;
      return _dragFor(edge) != CoilDrawerDrag.none;
    }
    final edge = _edgeOpenedBy(physicalRight: physicalRight);
    return _panel(edge) != null && _dragFor(edge) == CoilDrawerDrag.anywhere;
  }

  /// How a drag in that physical direction is routed between a scrollable
  /// in the content and this drawer, or the enclosing one.
  ///
  /// While a drag holds a drawer away from where it found it, it keeps the
  /// drag both ways, the way a sheet dragged down keeps a drag back up
  /// until it is at the top again: a scrollable under the finger takes over
  /// only once the drawer is back there.
  ScrollDragMode _modeFor({required bool physicalRight}) {
    for (_CoilDrawerState? drawer = this; drawer != null;) {
      if (drawer._holdsDrag) return ScrollDragMode.dragFirst;
      drawer = drawer._parent;
    }
    return _restingModeFor(physicalRight: physicalRight);
  }

  /// [_modeFor] while no drag holds this drawer or an enclosing one.
  ScrollDragMode _restingModeFor({required bool physicalRight}) {
    if (_uses(physicalRight: physicalRight)) {
      // From rest, only a drag that starts at the scrollable's edge opens
      // the drawer, so flicking back through a carousel never does.
      return _position.value == 0 && widget.open == null
          ? ScrollDragMode.boundaryStart
          : ScrollDragMode.scrollFirst;
    }
    return _parent?._restingModeFor(physicalRight: physicalRight) ??
        ScrollDragMode.none;
  }

  /// Updates [_holdsDrag] as the drawer moves, and rebuilds the drag
  /// detectors that route by it (this one and the nested drawers') when
  /// it changes.
  void _updateHold() {
    final holds = _dragging && _holdingScroll && _position.value != _dragOrigin;
    if (holds == _holdsDrag) return;
    _holdsDrag = holds;
    void rebuild() {
      void mark(_CoilDrawerState drawer) {
        if (!drawer.mounted) return;
        drawer.setState(() {});
        drawer._children.forEach(mark);
      }

      mark(this);
    }

    // Drag updates can arrive from scroll notifications during layout.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => rebuild());
    } else {
      rebuild();
    }
  }

  void _onDragStart({required bool fromScroll}) {
    _dragOwner = null;
    _dragDecided = false;
    _dragFromScroll = fromScroll;
  }

  void _onDragUpdate(double dx) {
    if (dx == 0) return;
    if (!_dragDecided) {
      // The first move's direction decides who moves: this drawer, or the
      // nearest enclosing one that can, or nobody.
      _dragDecided = true;
      _CoilDrawerState? owner = this;
      while (owner != null && !owner._uses(physicalRight: dx > 0)) {
        owner = owner._parent;
      }
      _dragOwner = owner?.._begin(fromScroll: _dragFromScroll);
    }
    _dragOwner?._move(dx);
  }

  void _onDragEnd(double velocity) {
    final owner = _dragOwner;
    _dragOwner = null;
    _dragDecided = false;
    owner?._end(velocity);
  }

  void _begin({required bool fromScroll}) {
    _dragging = true;
    _holdingScroll = fromScroll;
    final position = _position.value;
    _dragSide = position.abs() * _panelWidth > _restSlop
        ? position.sign
        : _targetOf(widget.open);
    _dragOrigin = _targetOf(widget.open);
    _position.value = position;
    _updateHold();
  }

  void _move(double dx) {
    if (!_dragging) return;
    final delta = dx / _panelWidth * (_startIsLeft ? 1 : -1);
    var next = _position.value + delta;
    if (_dragSide == 0) {
      // From rest, the first move picks the side.
      _dragSide = next.sign;
    }
    final edge = _dragSide > 0 ? CoilDrawerEdge.start : CoilDrawerEdge.end;
    if (_panel(edge) == null) return;
    next = _dragSide > 0 ? next.clamp(0.0, 1.0) : next.clamp(-1.0, 0.0);
    _position.value = next;
  }

  void _end(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    _updateHold();
    final side = _dragSide;
    _dragSide = 0;
    final position = _position.value;
    if (side == 0) {
      _animateTo(_targetOf(widget.open));
      return;
    }
    // Pixels per second toward this side's open position.
    final opening = velocity * (_startIsLeft ? 1 : -1) * side;
    final open = opening.abs() > CoilDrawer.flingVelocity
        ? opening > 0
        : position.abs() >= 0.5;
    final edge = side > 0 ? CoilDrawerEdge.start : CoilDrawerEdge.end;
    final result = open ? edge : null;
    _animateTo(
      _targetOf(result),
      velocity: velocity / _panelWidth * (_startIsLeft ? 1 : -1),
    );
    if (result == widget.open) return;
    widget.onOpenChanged(result);
    // An owner that doesn't apply the change (it keeps `open` as it was)
    // would leave the drawer where the drag sent it: go back.
    _schedule(() {
      if (!_dragging && widget.open != result && _target == _targetOf(result)) {
        _animateTo(_targetOf(widget.open));
      }
    });
  }

  // Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _panelWidth =
          widget.width ??
          math.min(
            CoilDrawer.maxWidth,
            constraints.maxWidth * CoilDrawer.widthFraction,
          );
      _look =
          widget.look ??
          CoilDrawerLook.fallback(CoilTheme.of(context), reveal: widget.reveal);
      final startIsLeft = _startIsLeft;
      final anyDrag =
          _uses(physicalRight: true) ||
          _uses(physicalRight: false) ||
          (_parent != null &&
              (_parent!._modeFor(physicalRight: true) != ScrollDragMode.none ||
                  _parent!._modeFor(physicalRight: false) !=
                      ScrollDragMode.none));
      // Its own layer, so a slide or a drag moves it without repainting
      // the page every frame.
      final content = RepaintBoundary(
        key: _contentKey,
        child: _CoilDrawerScope(state: this, child: widget.child),
      );
      return ScrollDragDetector(
        up: ScrollDragMode.none,
        down: ScrollDragMode.none,
        left: _modeFor(physicalRight: false),
        right: _modeFor(physicalRight: true),
        onHorizontalDragStart: anyDrag
            ? (_, fromScroll) => _onDragStart(fromScroll: fromScroll)
            : null,
        onHorizontalDragUpdate: anyDrag
            ? (details, _) => _onDragUpdate(details.primaryDelta ?? 0)
            : null,
        onHorizontalDragEnd: anyDrag
            ? (details, _) => _onDragEnd(details.primaryVelocity ?? 0)
            : null,
        onHorizontalDragCancel: anyDrag ? () => _onDragEnd(0) : null,
        child: AnimatedBuilder(
          animation: _position,
          builder: (context, _) {
            final position = _position.value;
            final atRest =
                position.abs() * _panelWidth <= _restSlop &&
                !_position.isAnimating &&
                !_dragging;
            final panels = [
              for (final edge in CoilDrawerEdge.values)
                if (_panel(edge) case final panel?)
                  _buildPanel(
                    edge: edge,
                    panel: panel,
                    position: position,
                    atRest: atRest,
                    startIsLeft: startIsLeft,
                  ),
            ];
            return switch (widget.reveal) {
              CoilDrawerReveal.behind => Stack(
                children: [
                  ...panels,
                  Positioned.fill(
                    child: _behindContent(
                      position: position,
                      atRest: atRest,
                      startIsLeft: startIsLeft,
                      child: content,
                    ),
                  ),
                ],
              ),
              CoilDrawerReveal.over => Stack(
                children: [
                  Positioned.fill(
                    child: _overContent(position: position, child: content),
                  ),
                  ...panels,
                ],
              ),
            };
          },
        ),
      );
    },
  );

  /// [color] at [strength] (0 to 1) of its alpha.
  static Color _faded(Color color, double strength) =>
      color.withValues(alpha: color.a * strength.clamp(0, 1));

  /// What covers the content while a panel shows: it closes on a press,
  /// and stands in for the content for screen readers.
  Widget _dismissLayer(double strength) => Semantics(
    onDismiss: _close,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      excludeFromSemantics: true,
      child: ColoredBox(color: _faded(_look.scrimColor, strength)),
    ),
  );

  Widget _behindContent({
    required double position,
    required bool atRest,
    required bool startIsLeft,
    required Widget child,
  }) {
    final theme = CoilTheme.of(context);
    final open = widget.open != null;
    final strength = position.abs();
    // Toward the physical right for a left panel.
    final dx = position * _panelWidth * (startIsLeft ? 1 : -1);
    final scale = 1 - (1 - widget.transition.scale) * strength.clamp(0, 1);
    final look = _look;
    final radius = atRest
        ? BorderRadius.zero
        : look.cornerRadius ??
              CoilScreenRadius.value ??
              look.fallbackCornerRadius;
    final shape = RoundedSuperellipseBorder(borderRadius: radius);
    // The edge fades in with the reveal: a raised surface's shadow and a
    // hairline in the border color.
    final shadows = atRest
        ? const <BoxShadow>[]
        : [
            for (final shadow in look.shadows)
              shadow.copyWith(color: _faded(shadow.color, strength)),
          ];
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Transform.scale(
        scale: scale,
        // Toward the far edge, so the panel stays fully revealed.
        alignment: dx >= 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            color: look.contentColor,
            shadows: shadows,
          ),

          child: DecoratedBox(
            // Over the content, which would hide it.
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: atRest
                    ? BorderSide.none
                    : BorderSide(
                        color: _faded(theme.colors.border, strength),
                      ),
              ),
            ),
            child: ClipRSuperellipse(
              borderRadius: radius,
              clipBehavior: atRest ? Clip.none : Clip.antiAlias,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  _ContentGate(open: open, child: child),
                  Positioned.fill(
                    child: Offstage(
                      offstage: atRest && !open,
                      child: IgnorePointer(
                        ignoring: !open && !_dragging,
                        child: _dismissLayer(strength),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overContent({required double position, required Widget child}) {
    final open = widget.open != null;
    final strength = position.abs();
    return Stack(
      fit: StackFit.passthrough,
      children: [
        _ContentGate(open: open, child: child),
        Positioned.fill(
          child: Offstage(
            offstage: strength == 0 && !open,
            child: IgnorePointer(
              ignoring: !open,
              child: _dismissLayer(strength),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel({
    required CoilDrawerEdge edge,
    required Widget panel,
    required double position,
    required bool atRest,
    required bool startIsLeft,
  }) {
    final sign = edge == CoilDrawerEdge.start ? 1.0 : -1.0;
    // How far this panel is out, 0 to 1.
    final shown = (position * sign).clamp(0.0, 1.0);
    final left = (edge == CoilDrawerEdge.start) == startIsLeft;
    final open = widget.open == edge;
    final hidden = !open && (atRest || shown == 0);
    final theme = CoilTheme.of(context);
    final label = edge == CoilDrawerEdge.start
        ? widget.startSemanticLabel
        : widget.endSemanticLabel;
    // Reduced motion keeps the fade and drops the growth.
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final transition = widget.transition;
    final panelScale = reduced ? 1.0 : transition.panelScale;
    // Its own layer, so the fade, growth or slide doesn't repaint it.
    final layer = RepaintBoundary(
      key: edge == CoilDrawerEdge.start ? _startKey : _endKey,
      child: panel,
    );
    var surface = switch (widget.reveal) {
      // The panel's content fades and grows in as the content uncovers it,
      // following the drag, from the edge the content leaves. Its fill
      // stays, so nothing shows through. Semantics follow `open` below,
      // not the fade.
      CoilDrawerReveal.behind => ColoredBox(
        color: _look.panelColor ?? theme.colors.background,
        child: Opacity(
          opacity:
              transition.panelOpacity + (1 - transition.panelOpacity) * shown,
          alwaysIncludeSemantics: true,
          child: Transform.scale(
            scale: panelScale + (1 - panelScale) * shown,
            alignment: left ? Alignment.centerRight : Alignment.centerLeft,
            child: layer,
          ),
        ),
      ),
      CoilDrawerReveal.over => CoilSurface(
        offset: CoilSurface.popoverOffset,
        shadowLevel: 3,
        borderRadius: BorderRadius.zero,
        color: _look.panelColor,
        child: layer,
      ),
    };
    surface = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: label,
      // Above the scope, so Escape also works while the scope itself
      // holds focus.
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): CoilDismissIntent(),
        },
        child: Actions(
          actions: {CoilDismissIntent: _dismiss},
          child: FocusScope(
            node: edge == CoilDrawerEdge.start ? _startScope : _endScope,
            child: surface,
          ),
        ),
      ),
    );
    if (widget.reveal == CoilDrawerReveal.over) {
      surface = FractionalTranslation(
        translation: Offset((1 - shown) * (left ? -1 : 1), 0),
        // The raised surface and its shadow slide as one layer.
        child: RepaintBoundary(child: BlockSemantics(child: surface)),
      );
    }
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: _panelWidth,
      child: Offstage(
        offstage: hidden,
        child: ExcludeFocus(
          excluding: !open,
          child: ExcludeSemantics(
            excluding: !open,
            child: IgnorePointer(
              ignoring: !open && !_dragging,
              child: surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Leaves the content out of focus, semantics and hit testing while a
/// panel is open. The dismiss layer above it speaks for it.
class _ContentGate extends StatelessWidget {
  const _ContentGate({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: open,
    child: ExcludeSemantics(
      excluding: open,
      child: IgnorePointer(ignoring: open, child: child),
    ),
  );
}

/// Lets a nested drawer hand drags to, and close, the one around it.
class _CoilDrawerScope extends InheritedWidget {
  const _CoilDrawerScope({required this.state, required super.child});

  final _CoilDrawerState state;

  @override
  bool updateShouldNotify(_CoilDrawerScope oldWidget) =>
      oldWidget.state != state;
}
