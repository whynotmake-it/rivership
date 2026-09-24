import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/style.dart';

/// A draggable bubble that settles on the nearest side of the screen and
/// morphs into [panel] while [isOpen].
class FloatingBubble extends StatefulWidget {
  /// Creates the floating bubble.
  const FloatingBubble({
    required this.isOpen,
    required this.onOpen,
    required this.initialAlignment,
    required this.isActive,
    required this.modifiedCount,
    required this.panel,
    super.key,
  });

  /// Whether the panel is shown.
  final bool isOpen;

  /// Called when the bubble is tapped.
  final VoidCallback onOpen;

  /// Where the bubble starts: the horizontal sign picks the side, the
  /// vertical component the height.
  final Alignment initialAlignment;

  /// Whether any controller is playing, shown as a dot on the bubble.
  final bool isActive;

  /// How many controllers the tools changed, shown as a badge on the bubble.
  final int modifiedCount;

  /// The expanded content.
  final Widget panel;

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble>
    with TickerProviderStateMixin {
  static const _size = 44.0;
  static const _margin = 12.0;
  static const _openMotion = Motion.cupertino(
    duration: Duration(milliseconds: 340),
    bounce: 0.06,
  );
  static const _closeMotion = Motion.smoothSpring(
    duration: Duration(milliseconds: 260),
  );
  static const _settleMotion = Motion.cupertino(
    duration: Duration(milliseconds: 420),
    bounce: 0.12,
  );

  late final _expansion = SingleMotionController(
    motion: _openMotion,
    vsync: this,
    initialValue: widget.isOpen ? 1 : 0,
    debugLabel: internalDebugLabel,
  );

  MotionController<Offset>? _position;

  /// How far the open panel is from its resting place, while it is dragged
  /// and settles.
  late final _shift = MotionController<Offset>(
    motion: _settleMotion,
    vsync: this,
    converter: MotionConverter.offset,
    initialValue: Offset.zero,
    debugLabel: internalDebugLabel,
  );
  final _shellKey = GlobalKey();
  var _dragging = false;
  Size? _stage;
  EdgeInsets _padding = EdgeInsets.zero;

  /// The bubble's resting place: the side, and the height as a fraction of
  /// the space it can move in.
  late var _onRight = widget.initialAlignment.x >= 0;
  late var _heightFraction = (widget.initialAlignment.y + 1) / 2;

  @override
  void didUpdateWidget(FloatingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen == widget.isOpen) return;
    if (!widget.isOpen) {
      _expansion
        ..motion = _closeMotion
        ..animateTo(0);
      return;
    }
    // Build and lay out the panel this frame; start growing next frame, so
    // the spring's first frames don't absorb the cost of the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isOpen) return;
      _expansion
        ..motion = _openMotion
        ..animateTo(1);
    });
  }

  @override
  void dispose() {
    _expansion.dispose();
    _position?.dispose();
    _shift.dispose();
    super.dispose();
  }

  Rect get _bounds => Rect.fromLTRB(
    _padding.left + _margin,
    _padding.top + _margin,
    _stage!.width - _padding.right - _margin - _size,
    _stage!.height - _padding.bottom - _margin - _size,
  );

  Offset get _restingOffset {
    final bounds = _bounds;
    return Offset(
      _onRight ? bounds.right : bounds.left,
      bounds.top +
          (bounds.height * _heightFraction).clamp(
            0,
            math.max(0, bounds.height),
          ),
    );
  }

  void _layout(Size stage, EdgeInsets padding) {
    final changed = stage != _stage || padding != _padding;
    _stage = stage;
    _padding = padding;
    final position = _position ??= MotionController<Offset>(
      motion: _settleMotion,
      vsync: this,
      converter: MotionConverter.offset,
      initialValue: _restingOffset,
      debugLabel: internalDebugLabel,
    );
    if (changed && !_dragging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_dragging) position.value = _restingOffset;
      });
    }
  }

  void _dragStart(DragStartDetails details) {
    setState(() => _dragging = true);
    _position!.stop(canceled: true);
  }

  void _dragUpdate(DragUpdateDetails details) {
    final position = _position!;
    position.value = position.value + details.delta;
  }

  void _dragEnd(DragEndDetails details) {
    final position = _position!;
    final velocity = details.velocity.pixelsPerSecond;
    final projected = position.value + velocity * 0.18;
    final bounds = _bounds;
    _onRight = projected.dx + _size / 2 > _stage!.width / 2;
    _heightFraction = bounds.height <= 0
        ? 0
        : ((projected.dy - bounds.top) / bounds.height).clamp(0.0, 1.0);
    position.animateTo(_restingOffset, withVelocity: velocity);
    setState(() => _dragging = false);
  }

  void _panelDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
    _shift.stop(canceled: true);
  }

  void _panelDragUpdate(DragUpdateDetails details) {
    _shift.value = _shift.value + details.delta;
  }

  /// Picks the side and height the panel was flung towards, moves the hidden
  /// bubble there, and springs the panel from where it was let go.
  void _panelDragEnd(DragEndDetails details) {
    final shell = _shellKey.currentContext?.findRenderObject();
    if (shell is! _RenderShell) return;
    final velocity = details.velocity.pixelsPerSecond;
    final from = shell.panel;
    final projected = from.shift(velocity * 0.18);
    final bounds = _bounds;
    _onRight = projected.center.dx > _stage!.width / 2;
    final bubbleTop = projected.center.dy < _stage!.height / 2
        ? projected.top
        : projected.bottom - _size;
    _heightFraction = bounds.height <= 0
        ? 0
        : ((bubbleTop - bounds.top) / bounds.height).clamp(0.0, 1.0);
    _position!
      ..stop(canceled: true)
      ..value = _restingOffset;
    final rest = shell.restingPanel(
      _restingOffset & const Size.square(_size),
      onRight: _onRight,
    );
    _shift
      ..value = from.topLeft - rest.topLeft
      ..animateTo(Offset.zero, withVelocity: velocity);
    setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(constraints.biggest, padding);
        return AnimatedBuilder(
          animation: Listenable.merge([_position, _expansion, _shift]),
          builder: (context, _) {
            final t = _expansion.value;
            final radius = _size / 2 + (18 - _size / 2) * t.clamp(0.0, 1.0);
            final bubble = _position!.value;
            final shell = _Shell(
              key: _shellKey,
              bubble: _position!.value & const Size.square(_size),
              shift: _shift.value,
              expansion: t,
              onRight: _onRight,
              padding: padding,
              radius: radius,
              frame: palette.frame,
              contentOpacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
              children: [
                SingleMotionBuilder(
                  value: _dragging && !widget.isOpen ? 1 : 0,
                  motion: quickMotion,
                  debugLabel: internalDebugLabel,
                  builder: (context, lift, child) => Transform.scale(
                    scale: 1 + lift * 0.08,
                    child: _Surface(
                      key: const ValueKey('motor-devtools-surface'),
                      radius: radius,
                      child: child!,
                    ),
                  ),
                  child: t < 0.5
                      ? IgnorePointer(
                          ignoring: widget.isOpen,
                          child: Opacity(
                            opacity: (1 - t * 3).clamp(0.0, 1.0),
                            child: _BubbleFace(
                              key: const ValueKey('motor-devtools-launcher'),
                              palette: palette,
                              isActive:
                                  widget.isActive && widget.modifiedCount == 0,
                              onTap: widget.onOpen,
                              onPanStart: _dragStart,
                              onPanUpdate: _dragUpdate,
                              onPanEnd: _dragEnd,
                            ),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
                if (t > 0.001 || widget.isOpen)
                  IgnorePointer(
                    ignoring: !widget.isOpen,
                    child: RawGestureDetector(
                      key: const ValueKey('motor-devtools-panel'),
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        _WindowDrag:
                            GestureRecognizerFactoryWithHandlers<_WindowDrag>(
                              _WindowDrag.new,
                              (recognizer) => recognizer
                                ..onStart = _panelDragStart
                                ..onUpdate = _panelDragUpdate
                                ..onEnd = _panelDragEnd,
                            ),
                      },
                      child: widget.panel,
                    ),
                  ),
              ],
            );
            // The badge sits on the bubble's edge, outside the surface's
            // clip.
            const edge = _size / 2 * math.sqrt1_2;
            return Stack(
              fit: StackFit.expand,
              children: [
                shell,
                Positioned(
                  left: bubble.dx + _size / 2 + edge,
                  top: bubble.dy + _size / 2 - edge,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - t * 3).clamp(0.0, 1.0),
                      child: _Badge(
                        count: widget.modifiedCount,
                        palette: palette,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A count centered on its position, that pops in and out.
class _Badge extends StatefulWidget {
  const _Badge({required this.count, required this.palette});

  final int count;
  final DevToolsPalette palette;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> {
  /// The last count shown, kept while the badge scales out.
  late var _shown = widget.count;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    if (widget.count > 0) _shown = widget.count;
    return FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: SingleMotionBuilder(
        value: widget.count > 0 ? 1 : 0,
        motion: quickMotion,
        debugLabel: internalDebugLabel,
        builder: (context, value, child) => value < 0.01
            ? const SizedBox.shrink()
            : Transform.scale(scale: value.clamp(0.0, 1.1), child: child),
        child: Container(
          key: const ValueKey('motor-devtools-badge'),
          constraints: const BoxConstraints(minWidth: 17),
          height: 17,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: palette.accent,
            shape: StadiumBorder(
              side: BorderSide(
                color: palette.surface,
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          ),
          child: Text(
            _shown > 99 ? '99+' : '$_shown',
            style: TextStyle(
              color: palette.surface,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out the panel first, then sizes the surface from the panel's height
/// in the same frame, morphing from the bubble by [expansion]. Its children
/// are the surface and, while shown, the panel.
class _Shell extends MultiChildRenderObjectWidget {
  const _Shell({
    required this.bubble,
    required this.shift,
    required this.expansion,
    required this.onRight,
    required this.padding,
    required this.radius,
    required this.frame,
    required this.contentOpacity,
    required super.children,
    super.key,
  });

  final Rect bubble;
  final Offset shift;
  final double expansion;
  final bool onRight;
  final EdgeInsets padding;
  final double radius;
  final Color frame;
  final double contentOpacity;

  @override
  _RenderShell createRenderObject(BuildContext context) => _RenderShell()
    ..bubble = bubble
    ..shift = shift
    ..expansion = expansion
    ..onRight = onRight
    ..padding = padding
    ..radius = radius
    ..frame = frame
    ..contentOpacity = contentOpacity;

  @override
  void updateRenderObject(BuildContext context, _RenderShell renderObject) {
    renderObject
      ..bubble = bubble
      ..shift = shift
      ..expansion = expansion
      ..onRight = onRight
      ..padding = padding
      ..radius = radius
      ..frame = frame
      ..contentOpacity = contentOpacity;
  }
}

class _ShellData extends ContainerBoxParentData<RenderBox> {}

class _RenderShell extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ShellData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ShellData> {
  static const _margin = 12.0;

  Rect _bubble = Rect.zero;
  Rect get bubble => _bubble;
  set bubble(Rect value) => _update(_bubble != value, () => _bubble = value);

  Offset _shift = Offset.zero;
  Offset get shift => _shift;
  set shift(Offset value) => _update(_shift != value, () => _shift = value);

  double _expansion = 0;
  double get expansion => _expansion;
  set expansion(double value) =>
      _update(_expansion != value, () => _expansion = value);

  bool _onRight = true;
  bool get onRight => _onRight;
  set onRight(bool value) => _update(_onRight != value, () => _onRight = value);

  EdgeInsets _padding = EdgeInsets.zero;
  EdgeInsets get padding => _padding;
  set padding(EdgeInsets value) =>
      _update(_padding != value, () => _padding = value);

  double _radius = 0;
  double get radius => _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  Color _frame = const Color(0x00000000);
  Color get frame => _frame;
  set frame(Color value) {
    if (_frame == value) return;
    _frame = value;
    markNeedsPaint();
  }

  double _contentOpacity = 0;
  double get contentOpacity => _contentOpacity;
  set contentOpacity(double value) {
    if (_contentOpacity == value) return;
    _contentOpacity = value;
    markNeedsPaint();
  }

  void _update(bool changed, VoidCallback apply) {
    if (!changed) return;
    apply();
    markNeedsLayout();
  }

  Rect _rect = Rect.zero;
  Size _panelSize = Size.zero;
  Rect _panel = Rect.zero;

  /// Where the open panel is, as of the last layout.
  Rect get panel => _panel;

  /// Where the open panel rests for a bubble at [bubble] on the side given
  /// by [onRight].
  Rect restingPanel(Rect bubble, {required bool onRight}) {
    final Size(:width, :height) = _panelSize;
    final left = onRight
        ? size.width - _padding.right - _margin - width
        : _padding.left + _margin;
    final anchorTop = bubble.center.dy < size.height / 2;
    final minTop = _padding.top + _margin;
    final maxTop = size.height - _padding.bottom - _margin - height;
    final top = (anchorTop ? bubble.top : bubble.bottom - height)
        .clamp(minTop, math.max(minTop, maxTop))
        .toDouble();
    return Rect.fromLTWH(left, top, width, height);
  }

  final _clip = LayerHandle<ClipRSuperellipseLayer>();
  final _opacity = LayerHandle<OpacityLayer>();

  RenderBox? get _content => childAfter(firstChild!);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ShellData) child.parentData = _ShellData();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    // In a window too small for it, the panel keeps a usable size and
    // runs past the window's edges rather than squeezing its content.
    final width = math.max<double>(
      280,
      math.min(380, size.width - _padding.horizontal - _margin * 2),
    );
    final maxHeight = math.max<double>(
      240,
      math.min(640, size.height - _padding.vertical - _margin * 2),
    );
    final content = _content;
    var height = 0.0;
    if (content != null) {
      content.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: math.max(0, maxHeight),
        ),
        parentUsesSize: true,
      );
      height = content.size.height;
    }
    _panelSize = Size(width, height);
    final anchorTop = _bubble.center.dy < size.height / 2;
    final panel = restingPanel(_bubble, onRight: _onRight).shift(_shift);
    _panel = panel;
    final rect = Rect.lerp(_bubble, panel, _expansion)!;
    _rect = Rect.fromLTWH(
      rect.left,
      rect.top,
      math.max(0, rect.width),
      math.max(0, rect.height),
    );
    final surface = firstChild!..layout(BoxConstraints.tight(_rect.size));
    (surface.parentData! as _ShellData).offset = _rect.topLeft;
    if (content != null) {
      (content.parentData! as _ShellData).offset = Offset(
        _onRight ? _rect.right - width : _rect.left,
        anchorTop ? _rect.top : _rect.bottom - height,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final surface = firstChild!;
    context.paintChild(
      surface,
      offset + (surface.parentData! as _ShellData).offset,
    );
    final content = _content;
    if (content == null || _contentOpacity <= 0) {
      _clip.layer = null;
      _opacity.layer = null;
      return;
    }
    final at = (content.parentData! as _ShellData).offset;
    _clip.layer = context.pushClipRSuperellipse(
      needsCompositing,
      offset,
      _rect,
      RSuperellipse.fromRectAndRadius(_rect, Radius.circular(_radius)),
      (context, offset) {
        if (_contentOpacity >= 1) {
          _opacity.layer = null;
          context.paintChild(content, offset + at);
          return;
        }
        _opacity.layer = context.pushOpacity(
          offset,
          (_contentOpacity * 255).round(),
          (context, offset) => context.paintChild(content, offset + at),
          oldLayer: _opacity.layer,
        );
      },
      oldLayer: _clip.layer,
    );
    // The panel's own backgrounds cover the surface's edge, so the frame is
    // drawn again on top.
    context.canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        _rect.shift(offset).deflate(0.25),
        Radius.circular(math.max(0, _radius - 0.25)),
      ),
      Paint()
        ..color = _frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final content = _content;
    if (content != null && _rect.contains(position)) {
      final at = (content.parentData! as _ShellData).offset;
      final hit = result.addWithPaintOffset(
        offset: at,
        position: position,
        hitTest: (result, position) =>
            content.hitTest(result, position: position),
      );
      if (hit) return true;
    }
    final surface = firstChild!;
    return result.addWithPaintOffset(
      offset: (surface.parentData! as _ShellData).offset,
      position: position,
      hitTest: (result, position) =>
          surface.hitTest(result, position: position),
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    _opacity.layer = null;
    super.dispose();
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.radius, required this.child, super.key});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: rounded(radius, side: palette.frame, sideWidth: 0.5),
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _BubbleFace extends StatelessWidget {
  const _BubbleFace({
    required this.palette,
    required this.isActive,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final DevToolsPalette palette;
  final bool isActive;
  final VoidCallback onTap;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open Motor devtools',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: onTap,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: OverflowBox(
          minWidth: 44,
          maxWidth: 44,
          minHeight: 44,
          maxHeight: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GlyphIcon(Glyph.logo, color: palette.text, size: 22),
              Positioned(
                top: 10,
                right: 10,
                child: SingleMotionBuilder(
                  value: isActive ? 1 : 0,
                  motion: quickMotion,
                  debugLabel: internalDebugLabel,
                  builder: (context, value, _) => Transform.scale(
                    scale: value.clamp(0.0, 1.2),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pans the open window, except for pointers that a control holds.
class _WindowDrag extends PanGestureRecognizer {
  @override
  bool isPointerAllowed(PointerEvent event) =>
      !heldPointers.contains(event.pointer) && super.isPointerAllowed(event);
}
