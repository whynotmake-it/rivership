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
    required this.activity,
    required this.isActive,
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

  /// Notifies when [isActive] may have changed.
  final Listenable activity;

  /// Whether any controller is playing, shown as a dot on the bubble.
  final bool Function() isActive;

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
    duration: Duration(milliseconds: 460),
    bounce: 0.12,
  );
  static const _closeMotion = Motion.smoothSpring(
    duration: Duration(milliseconds: 360),
  );

  late final _expansion = SingleMotionController(
    motion: _openMotion,
    vsync: this,
    initialValue: widget.isOpen ? 1 : 0,
    debugLabel: internalDebugLabel,
  );

  late final _contentHeight = SingleMotionController(
    motion: const Motion.smoothSpring(duration: Duration(milliseconds: 380)),
    vsync: this,
    debugLabel: internalDebugLabel,
  );
  var _measured = false;

  MotionController<Offset>? _position;
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
    _expansion
      ..motion = widget.isOpen ? _openMotion : _closeMotion
      ..animateTo(widget.isOpen ? 1 : 0);
  }

  @override
  void dispose() {
    _expansion.dispose();
    _contentHeight.dispose();
    _position?.dispose();
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
      motion: const Motion.cupertino(
        duration: Duration(milliseconds: 520),
        bounce: 0.2,
      ),
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

  void _measuredContent(Size size) {
    if (!mounted) return;
    if (_measured && _expansion.value > 0.01) {
      _contentHeight.animateTo(size.height);
    } else {
      _contentHeight.value = size.height;
    }
    _measured = true;
  }

  double get _maxPanelHeight => math.min<double>(
    640,
    _stage!.height - _padding.vertical - _margin * 2,
  );

  Rect _panelRect(Offset bubble) {
    final stage = _stage!;
    final width = math.min<double>(
      380,
      stage.width - _padding.horizontal - _margin * 2,
    );
    final height = _measured
        ? math.min(_contentHeight.value, _maxPanelHeight)
        : _maxPanelHeight;
    final left = _onRight
        ? stage.width - _padding.right - _margin - width
        : _padding.left + _margin;
    final minTop = _padding.top + _margin;
    final maxTop = stage.height - _padding.bottom - _margin - height;
    final top = bubble.dy + _size / 2 < stage.height / 2
        ? bubble.dy
        : bubble.dy + _size - height;
    return Rect.fromLTWH(
      left,
      top.clamp(minTop, math.max(minTop, maxTop)),
      width,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(constraints.biggest, padding);
        return AnimatedBuilder(
          animation: Listenable.merge([_position, _expansion, _contentHeight]),
          builder: (context, _) {
            final t = _expansion.value;
            final bubble = _position!.value;
            final bubbleRect = bubble & const Size.square(_size);
            final panelRect = _panelRect(bubble);
            final rect = Rect.lerp(bubbleRect, panelRect, t)!;
            final showPanel = t > 0.001 || widget.isOpen;
            final anchor = Alignment(
              _onRight ? 1 : -1,
              bubble.dy + _size / 2 < _stage!.height / 2 ? -1 : 1,
            );
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: SingleMotionBuilder(
                    value: _dragging ? 1 : 0,
                    motion: quickMotion,
                    debugLabel: internalDebugLabel,
                    builder: (context, lift, child) => Transform.scale(
                      scale: 1 + lift * 0.08,
                      child: _Surface(
                        radius:
                            _size / 2 + (16 - _size / 2) * t.clamp(0.0, 1.0),
                        elevation: 1 + lift,
                        child: child!,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (showPanel)
                          IgnorePointer(
                            ignoring: !widget.isOpen,
                            child: Opacity(
                              opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
                              child: OverflowBox(
                                alignment: anchor,
                                minWidth: panelRect.width,
                                maxWidth: panelRect.width,
                                minHeight: 0,
                                maxHeight: _maxPanelHeight,
                                child: _SizeReporter(
                                  key: const ValueKey('motor-devtools-panel'),
                                  onSize: _measuredContent,
                                  child: widget.panel,
                                ),
                              ),
                            ),
                          ),
                        if (t < 0.5)
                          IgnorePointer(
                            ignoring: widget.isOpen,
                            child: Opacity(
                              opacity: (1 - t * 3).clamp(0.0, 1.0),
                              child: _BubbleFace(
                                key: const ValueKey('motor-devtools-launcher'),
                                palette: palette,
                                activity: widget.activity,
                                isActive: widget.isActive,
                                onTap: widget.onOpen,
                                onPanStart: _dragStart,
                                onPanUpdate: _dragUpdate,
                                onPanEnd: _dragEnd,
                              ),
                            ),
                          ),
                      ],
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

class _Surface extends StatelessWidget {
  const _Surface({
    required this.radius,
    required this.elevation,
    required this.child,
  });

  final double radius;
  final double elevation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: shape.copyWith(side: BorderSide(color: palette.hairline)),
        shadows: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 12 + 12 * elevation,
            offset: Offset(0, 4 + 4 * elevation),
          ),
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: child,
      ),
    );
  }
}

class _BubbleFace extends StatelessWidget {
  const _BubbleFace({
    required this.palette,
    required this.activity,
    required this.isActive,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final DevToolsPalette palette;
  final Listenable activity;
  final bool Function() isActive;
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
              GlyphIcon(Glyph.mark, color: palette.text, size: 22),
              Positioned(
                top: 10,
                right: 10,
                child: ListenableBuilder(
                  listenable: activity,
                  builder: (context, _) => SingleMotionBuilder(
                    value: isActive() ? 1 : 0,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reports its child's size after each layout that changes it.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child, super.key});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    _reported = size;
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}
