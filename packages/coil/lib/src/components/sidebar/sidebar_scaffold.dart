import 'dart:async';
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_controller.dart';
import 'package:coil/src/components/sidebar/sidebar_rail.dart';
import 'package:coil/src/components/sidebar/sidebar_scope.dart';
import 'package:coil/src/components/sidebar/sidebar_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSidebarScaffold]. Use them as keys of
/// [CoilSidebarScaffold.motions] or [CoilThemeData.trackMotions].
final class CoilSidebarTrack<T extends Object> extends Track<T> {
  CoilSidebarTrack._(super.converter, {required String super.debugLabel});

  /// The width the sidebar takes beside the page. Default motion:
  /// `gentle` opening, `gentleExit` closing. A rail drag follows the
  /// pointer at once.
  static final width = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.width',
  );

  /// How far a peek has floated out, 0 to 1. Default motion: `standard`
  /// in, `standardExit` out.
  static final peek = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.peek',
  );

  /// A callout pile fanning out, and each card moving to its place in it.
  /// Default motion: `standard`, and `standardExit` as the pile folds.
  static final callouts = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.callouts',
  );

  /// The hover fill gliding between menu rows. Default motion: `quick`.
  static final highlight = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.highlight',
  );

  /// The selected row's fill gliding when the selection moves. Default
  /// motion: `standard`.
  static final selection = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.selection',
  );

  /// A group or a sub-tree folding open or closed. Default motion:
  /// `standard`, and `standardExit` as it closes.
  static final expand = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.expand',
  );

  /// The phone drawer sliding in and out. Default motion: `standard` in,
  /// `standardExit` out. A drag follows the finger.
  static final drawer = CoilSidebarTrack<double>._(
    .single,
    debugLabel: 'CoilSidebar.drawer',
  );
}

/// A page with a [sidebar] beside its [body].
///
/// The sidebar sits on [side] in the way [variant] describes. With
/// [CoilSidebarCollapsible.offcanvas], it folds off the edge and back:
/// through a `CoilSidebarTrigger`, the [rail], the [shortcuts] while focus
/// is inside the scaffold, or the [controller]. Folded, its edge can
/// [peek] it back over the page. Below [drawerBreakpoint] it hides and
/// opens as a modal drawer instead, which a pick in a sidebar menu, a press
/// on the scrim, Escape, a drag or system back closes.
///
/// There is no icon-only rail on purpose: folded means gone, and [peek]
/// brings the whole sidebar back, labels and all.
class CoilSidebarScaffold extends StatefulWidget {
  /// Creates a sidebar scaffold.
  const CoilSidebarScaffold({
    required this.sidebar,
    required this.body,
    super.key,
    this.controller,
    this.side = CoilSidebarSide.start,
    this.variant = CoilSidebarVariant.sidebar,
    this.collapsible = CoilSidebarCollapsible.offcanvas,
    this.peek = CoilSidebarPeek.none,
    this.rail = const CoilSidebarRail(),
    this.shortcuts,
    this.autofocus = true,
    this.drawerBreakpoint = 768,
    this.minWidth = 160,
    this.maxWidth = 360,
    this.drawerLabel = 'Sidebar',
    this.peekLabel = 'Peek sidebar',
    this.style,
    this.motion,
    this.motions,
  });

  /// The sidebar, usually a `CoilSidebar`.
  final Widget sidebar;

  /// The page.
  final Widget body;

  /// Whether the sidebar is open, and its width. The scaffold creates one
  /// when null.
  final CoilSidebarController? controller;

  /// The edge the sidebar sits on.
  final CoilSidebarSide side;

  /// How the sidebar sits beside the page.
  final CoilSidebarVariant variant;

  /// Whether the sidebar folds away.
  final CoilSidebarCollapsible collapsible;

  /// What the folded edge does.
  final CoilSidebarPeek peek;

  /// The handle on the sidebar's inner edge, usually a [CoilSidebarRail].
  /// Null shows none; the trigger and the shortcuts still toggle.
  final Widget? rail;

  /// The keys that toggle the sidebar while focus is inside the scaffold,
  /// the innermost one when scaffolds nest.
  ///
  /// Null is `[` for a sidebar on the left, `]` on the right, and ⌘B
  /// (Ctrl+B off Apple platforms). Empty disables them. They do nothing
  /// while focus is in a text field.
  final Set<ShortcutActivator>? shortcuts;

  /// Whether the scaffold takes focus when nothing else has it, so the
  /// [shortcuts] answer right after launch. A scaffold inside another one
  /// never does; turn it off where several sit side by side.
  final bool autofocus;

  /// Below this width, the scaffold's own and not the window's, the
  /// sidebar becomes a drawer.
  final double drawerBreakpoint;

  /// The narrowest the rail resizes the sidebar to.
  final double minWidth;

  /// The widest the rail resizes the sidebar to.
  final double maxWidth;

  /// The drawer's name for screen readers.
  final String drawerLabel;

  /// The peek edge's name for screen readers.
  final String peekLabel;

  /// Overrides the theme's sidebar style.
  final CoilSidebarStyle? style;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this instance, keyed by [CoilSidebarTrack]s.
  final Map<CoilSidebarTrack<Object>, Motion>? motions;

  /// The controller of the nearest scaffold.
  static CoilSidebarController of(BuildContext context) {
    final scope = CoilSidebarScope.maybeOf(context);
    assert(scope != null, 'No CoilSidebarScaffold above this context.');
    return scope!.controller;
  }

  @override
  State<CoilSidebarScaffold> createState() => _CoilSidebarScaffoldState();
}

class _CoilSidebarScaffoldState extends State<CoilSidebarScaffold> {
  CoilSidebarController? _ownController;
  CoilSidebarController get _controller =>
      widget.controller ?? (_ownController ??= CoilSidebarController());

  /// Moves the one sidebar between the column and the peek card, so it
  /// keeps its state.
  final _sidebarKey = GlobalKey(debugLabel: 'CoilSidebarScaffold.sidebar');
  final _peekCardKey = GlobalKey(debugLabel: 'CoilSidebarScaffold.peek');

  /// Whether the scaffold was narrower than [CoilSidebarScaffold.
  /// drawerBreakpoint] at its last layout.
  bool _compact = false;

  bool _resizing = false;

  /// Whether a rail drag flipped the sidebar open or closed, and the width
  /// hasn't settled since: the flip springs instead of tracking.
  bool _flipping = false;

  bool _peeking = false;
  Timer? _peekTimer;
  bool _pointerWasInPeek = true;
  final _stripStates = WidgetStatesController();

  bool _drawerOpen = false;

  /// The scaffold is a focus scope, so focus that a folding sidebar drops
  /// lands on the scaffold and the shortcuts keep answering. Tab still
  /// flows on past its edges.
  final _focusScope = FocusScopeNode(
    debugLabel: 'CoilSidebarScaffold',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  @override
  void initState() {
    super.initState();
    _controller
      ..attach(_toggle)
      ..addListener(_onController);
    _stripStates.addListener(_onStripStates);
  }

  @override
  void didUpdateWidget(CoilSidebarScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _ownController;
    if (old != _controller) {
      old
        ?..attach(null)
        ..removeListener(_onController);
      _controller
        ..attach(_toggle)
        ..addListener(_onController);
    }
    if (!_peekAllowed) _dropPeek();
  }

  @override
  void dispose() {
    _dropPeek();
    _controller
      ..attach(null)
      ..removeListener(_onController);
    _ownController?.dispose();
    _stripStates.dispose();
    _focusScope.dispose();
    super.dispose();
  }

  bool _lastOpen = true;

  void _onController() {
    final open = _controller.open;
    if (open != _lastOpen) {
      _lastOpen = open;
      if (_resizing) _flipping = true;
      if (open) _dropPeek();
    }
    setState(() {});
  }

  bool get _offcanvas => widget.collapsible == CoilSidebarCollapsible.offcanvas;

  void _toggle() {
    if (!_offcanvas) return;
    if (_compact) {
      _drawerOpen ? _closeDrawer() : _openDrawer();
      return;
    }
    _controller.open = !_controller.open;
  }

  // Drawer -----------------------------------------------------------------

  void _openDrawer() => setState(() => _drawerOpen = true);

  void _closeDrawer() {
    if (_drawerOpen) setState(() => _drawerOpen = false);
  }

  // Peek -------------------------------------------------------------------

  bool get _peekAllowed =>
      widget.peek != CoilSidebarPeek.none &&
      _offcanvas &&
      !_compact &&
      !_controller.open &&
      !_resizing;

  void _armPeek() {
    if (!_peekAllowed) return;
    _peekTimer?.cancel();
    if (_peeking) return;
    _peekTimer = Timer(const Duration(milliseconds: 150), _startPeek);
  }

  void _disarmPeek() {
    // While peeking, the pointer watch decides when it ends.
    if (!_peeking) _peekTimer?.cancel();
  }

  void _onStripStates() {
    if (widget.peek != CoilSidebarPeek.hover) return;
    if (_stripStates.value.contains(WidgetState.hovered)) {
      _armPeek();
    } else {
      _disarmPeek();
    }
  }

  void _startPeek() {
    _peekTimer?.cancel();
    if (!_peekAllowed || _peeking) return;
    _pointerWasInPeek = true;
    _startPeekWatch();
    setState(() => _peeking = true);
  }

  void _endPeek() {
    if (!_peeking) {
      _peekTimer?.cancel();
      return;
    }
    setState(_dropPeek);
  }

  /// Ends a peek without a rebuild, for callers that rebuild anyway.
  void _dropPeek() {
    _peekTimer?.cancel();
    if (!_peeking) return;
    _stopPeekWatch();
    _peeking = false;
  }

  void _startPeekWatch() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _stopPeekWatch() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
  }

  Rect? get _peekRect {
    final box = _peekCardKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // The peek holds by where the pointer is, not by enter and exit: a
  // tooltip or menu opened from the card covers it and would fire an exit
  // although the pointer never left.
  void _onGlobalPointer(PointerEvent event) {
    final rect = _peekRect;
    if (rect == null) return;
    if (event is PointerDownEvent && !rect.contains(event.position)) {
      _endPeek();
      return;
    }
    if (widget.peek != CoilSidebarPeek.hover ||
        event is! PointerHoverEvent ||
        !CoilInputModality.canHover(event.kind)) {
      return;
    }
    if (rect.inflate(8).contains(event.position)) {
      _pointerWasInPeek = true;
      _peekTimer?.cancel();
    } else if (_pointerWasInPeek) {
      _pointerWasInPeek = false;
      _peekTimer?.cancel();
      _peekTimer = Timer(const Duration(milliseconds: 250), _endPeek);
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    _endPeek();
    return true;
  }

  // Build ------------------------------------------------------------------

  Motion _motionFor(CoilSidebarTrack<Object> track, Motion token) =>
      CoilTheme.trackMotionOf(
        context,
        track,
        instance: widget.motions,
        token: token,
      );

  bool get _physicalLeft =>
      (widget.side == CoilSidebarSide.start) ==
      (Directionality.of(context) == TextDirection.ltr);

  Set<ShortcutActivator> get _shortcuts {
    if (widget.shortcuts case final shortcuts?) return shortcuts;
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    return {
      CharacterActivator(_physicalLeft ? '[' : ']'),
      SingleActivator(LogicalKeyboardKey.keyB, meta: apple, control: !apple),
    };
  }

  CoilSidebarScopeData _scope({required bool drawer}) => CoilSidebarScopeData(
    controller: _controller,
    side: widget.side,
    physicalLeft: _physicalLeft,
    drawer: drawer,
    peeking: _peeking,
    peekMode: _peekAllowed ? widget.peek : CoilSidebarPeek.none,
    shortcutLabel: _physicalLeft ? '[' : ']',
    toggle: _toggle,
    closeDrawer: _closeDrawer,
    armPeek: _armPeek,
    disarmPeek: _disarmPeek,
    setResizing: (resizing) {
      if (resizing == _resizing) return;
      setState(() {
        _resizing = resizing;
        if (!resizing) _flipping = false;
      });
    },
    minWidth: widget.minWidth,
    maxWidth: widget.maxWidth,
  );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final look = CoilSidebarStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilSidebarStyle>(context)).merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < widget.drawerBreakpoint;
        if (compact != _compact) {
          _compact = compact;
          if (compact) _dropPeek();
        }
        var content = !_offcanvas
            ? _static(look)
            : _withDrawer(look, compact ? widget.body : _wide(look));
        // With nothing focused yet, the scaffold takes focus itself, so the
        // shortcuts answer right after launch; when scaffolds nest, the
        // outermost one does, as on the web.
        content = FocusScope(
          node: _focusScope,
          autofocus:
              widget.autofocus && CoilSidebarScope.maybeOf(context) == null,
          child: content,
        );
        if (_offcanvas) {
          content = Shortcuts(
            shortcuts: {
              for (final activator in _shortcuts)
                activator: const _ToggleSidebarIntent(),
            },
            child: Actions(
              actions: {_ToggleSidebarIntent: _ToggleSidebarAction(_toggle)},
              child: content,
            ),
          );
        }
        return CoilSidebarScope(
          data: _scope(drawer: false),
          child: content,
        );
      },
    );
  }

  /// The sidebar as a fixed column, for [CoilSidebarCollapsible.none].
  Widget _static(CoilSidebarStyle look) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    textDirection: _rowDirection,
    children: [
      SizedBox(
        width: _controller.width,
        child: _Panel(
          variant: widget.variant,
          physicalLeft: _physicalLeft,
          look: look,
          child: KeyedSubtree(key: _sidebarKey, child: widget.sidebar),
        ),
      ),
      Expanded(child: _page(look, open: 1)),
    ],
  );

  /// The row's order puts the sidebar on its physical edge whatever the
  /// text direction.
  TextDirection get _rowDirection =>
      _physicalLeft ? TextDirection.ltr : TextDirection.rtl;

  /// The page, framed as a card for the inset variant. [open] is how much
  /// of the sidebar shows, 0 to 1: the card's margin on the sidebar's side
  /// gives way as it opens.
  Widget _page(CoilSidebarStyle look, {required double open}) {
    final body = widget.body;
    if (widget.variant != CoilSidebarVariant.inset) return body;
    final inset = look.inset!;
    final near = inset * (1 - open.clamp(0, 1));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _physicalLeft ? near : inset,
        inset,
        _physicalLeft ? inset : near,
        inset,
      ),
      child: _Card(child: body),
    );
  }

  Widget _wide(CoilSidebarStyle look) {
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final open = _controller.open;
    final width = _controller.width;
    final widthMotion = _resizing && !_flipping
        ? const Motion.instant()
        : _motionFor(
            CoilSidebarTrack.width,
            open
                ? (_resizing ? motion.standard : motion.gentle)
                : (_resizing ? motion.standardExit : motion.gentleExit),
          );
    final peekMotion = _motionFor(
      CoilSidebarTrack.peek,
      _peeking ? motion.standard : motion.standardExit,
    );
    final armed = _peekAllowed;
    final sidebar = KeyedSubtree(key: _sidebarKey, child: widget.sidebar);
    return TrackBuilder(
      initialValues: [
        CoilSidebarTrack.width.value(open ? width : 0.0),
        CoilSidebarTrack.peek.value(0),
      ],
      animations: [
        CoilSidebarTrack.width([.to(open ? width : 0.0, motion: widthMotion)]),
        CoilSidebarTrack.peek([.to(_peeking ? 1.0 : 0.0, motion: peekMotion)]),
      ],
      onAnimationStatusChanged: (status) {
        if (!status.isAnimating && _flipping && !_resizing) {
          setState(() => _flipping = false);
        }
      },
      builder: (context, value, _) {
        final shown = math.max(0, value(CoilSidebarTrack.width)).toDouble();
        final peek = value(CoilSidebarTrack.peek);
        final progress = width > 0 ? shown / width : 0.0;
        // Folded and settled, the column is gone; peeking, the sidebar
        // lives in the card instead.
        final inColumn = open || shown > 0.5 || !armed;
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: _rowDirection,
              children: [
                SizedBox(
                  width: shown,
                  child: Offstage(
                    offstage: !open && shown <= 0.5,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: _physicalLeft
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        minWidth: width,
                        maxWidth: width,
                        child: _Excluded(
                          excluded: !open,
                          child: _Panel(
                            variant: widget.variant,
                            physicalLeft: _physicalLeft,
                            look: look,
                            rail: widget.rail,
                            child: inColumn ? sidebar : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _page(look, open: progress)),
              ],
            ),
            if (armed) ...[
              Positioned(
                top: 0,
                bottom: 0,
                left: _physicalLeft ? 0 : null,
                right: _physicalLeft ? null : 0,
                width: 12,
                child: _PeekStrip(
                  states: _stripStates,
                  label: widget.peekLabel,
                  physicalLeft: _physicalLeft,
                  look: look,
                  expanded: _peeking,
                  onPressed: _startPeek,
                ),
              ),
              _peekCard(look, width, peek, inColumn ? null : sidebar),
            ],
          ],
        );
      },
    );
  }

  Widget _peekCard(
    CoilSidebarStyle look,
    double width,
    double peek,
    Widget? sidebar,
  ) {
    final inset = look.inset!;
    // The card's edge sits where the open sidebar's content sits, so
    // pinning it open doesn't shift the rows sideways.
    final edge = widget.variant == CoilSidebarVariant.floating ? inset : 0.0;
    final cardWidth =
        width - (widget.variant == CoilSidebarVariant.floating ? 2 : 1) * inset;
    return Positioned(
      top: inset,
      bottom: inset,
      left: _physicalLeft ? edge : null,
      right: _physicalLeft ? null : edge,
      width: cardWidth,
      // Hidden, the card keeps the folded sidebar's state.
      child: Offstage(
        offstage: !_peeking && peek <= 0,
        child: FractionalTranslation(
          translation: Offset((1 - peek) * 1.08 * (_physicalLeft ? -1 : 1), 0),
          child: _Excluded(
            excluded: !_peeking,
            child: CoilSurface(
              key: _peekCardKey,
              offset: 1,
              shadowLevel: 3,
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(
                  CoilTheme.radiiOf(context).container,
                ),
                child: sidebar ?? const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [child] with the phone drawer above it. The drawer stays put if the
  /// window widens while it is open, until it is closed.
  Widget _withDrawer(CoilSidebarStyle look, Widget child) {
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    return CoilDrawer(
      open: _drawerOpen,
      onClose: _closeDrawer,
      edge: widget.side == CoilSidebarSide.start
          ? CoilDrawerEdge.start
          : CoilDrawerEdge.end,
      semanticLabel: widget.drawerLabel,
      motion: _motionFor(CoilSidebarTrack.drawer, motion.standard),
      exitMotion: _motionFor(CoilSidebarTrack.drawer, motion.standardExit),
      drawer: CoilSidebarScope(
        data: _scope(drawer: true),
        // Wide, the column holds the sidebar and its state; a drawer left
        // open while the window widened shows a second copy until closed.
        child: _compact
            ? KeyedSubtree(key: _sidebarKey, child: widget.sidebar)
            : _drawerOpen
            ? widget.sidebar
            : const SizedBox.shrink(),
      ),
      child: child,
    );
  }
}

/// Leaves a folded sidebar out of focus, semantics and hit testing.
class _Excluded extends StatelessWidget {
  const _Excluded({required this.excluded, required this.child});

  final bool excluded;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: excluded,
    child: ExcludeSemantics(
      excluding: excluded,
      child: IgnorePointer(ignoring: excluded, child: child),
    ),
  );
}

/// The sidebar's frame for its [variant], with the [rail] on its inner
/// edge.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.variant,
    required this.physicalLeft,
    required this.look,
    required this.child,
    this.rail,
  });

  final CoilSidebarVariant variant;
  final bool physicalLeft;
  final CoilSidebarStyle look;
  final Widget? rail;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final inset = look.inset!;
    final content = child ?? const SizedBox.shrink();
    final Widget panel = switch (variant) {
      CoilSidebarVariant.sidebar => ColoredBox(
        color: look.background ?? const Color(0x00000000),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(
              right: physicalLeft
                  ? BorderSide(color: look.edgeColor!)
                  : BorderSide.none,
              left: physicalLeft
                  ? BorderSide.none
                  : BorderSide(color: look.edgeColor!),
            ),
          ),
          child: content,
        ),
      ),
      CoilSidebarVariant.floating => Padding(
        padding: EdgeInsets.all(inset),
        child: CoilSurface(
          offset: 1,
          shadowLevel: 3,
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(
              CoilTheme.radiiOf(context).container,
            ),
            child: content,
          ),
        ),
      ),
      CoilSidebarVariant.inset => Padding(
        padding: EdgeInsets.symmetric(vertical: inset),
        child: content,
      ),
    };
    final rail = this.rail;
    if (rail == null) return panel;
    // The grab strip straddles the visible edge: the card's for floating,
    // the column's otherwise.
    final railEdge = variant == CoilSidebarVariant.floating ? inset / 2 : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        panel,
        Positioned(
          top: variant == CoilSidebarVariant.sidebar ? 0 : inset,
          bottom: variant == CoilSidebarVariant.sidebar ? 0 : inset,
          right: physicalLeft ? railEdge : null,
          left: physicalLeft ? null : railEdge,
          width: 8,
          child: rail,
        ),
      ],
    );
  }
}

/// The inset variant's page card.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return CoilSurface(
      offset: 1,
      borderRadius: radius,
      child: ClipRSuperellipse(borderRadius: radius, child: child),
    );
  }
}

/// The folded sidebar's edge: a strip that peeks it, with a hairline that
/// brightens on hover.
class _PeekStrip extends StatelessWidget {
  const _PeekStrip({
    required this.states,
    required this.label,
    required this.physicalLeft,
    required this.look,
    required this.expanded,
    required this.onPressed,
  });

  final WidgetStatesController states;
  final String label;
  final bool physicalLeft;
  final CoilSidebarStyle look;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      onTap: onPressed,
      child: CoilInteractionDetector(
        states: states,
        onTap: onPressed,
        excludeFromSemantics: true,
        cursor: SystemMouseCursors.click,
        child: ValueListenableBuilder(
          valueListenable: states,
          builder: (context, value, _) {
            final hovered = value.contains(WidgetState.hovered);
            return SingleMotionBuilder(
              value: hovered ? 1 : 0,
              motion: hovered ? motion.fade : motion.fadeExit,
              builder: (context, opacity, _) => Align(
                alignment: physicalLeft
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: SizedBox(
                  width: 1,
                  height: double.infinity,
                  child: ColoredBox(
                    color: look.edgeColor!.withValues(
                      alpha: look.edgeColor!.a * opacity.clamp(0, 1),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

/// Toggles the sidebar, except while focus is in a text field, so the
/// bare keys still type.
class _ToggleSidebarAction extends Action<_ToggleSidebarIntent> {
  _ToggleSidebarAction(this.toggle);

  final VoidCallback toggle;

  @override
  bool isEnabled(_ToggleSidebarIntent intent, [BuildContext? context]) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return true;
    return focused.widget is! EditableText &&
        focused.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  @override
  Object? invoke(_ToggleSidebarIntent intent) {
    toggle();
    return null;
  }
}
