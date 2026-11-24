/// @docImport 'package:snaptest/src/video/video_settings.dart';
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:snaptest/src/video/video_frame.dart';

/// Shows where pointers are in a recording, like a screen recorder's
/// "show touches".
///
/// Pass [SnapPointerOverlay.builder] as [SnapVideoSettings.overlay] to use
/// it on its own. Each pointer
/// gets a ring-and-dot indicator that:
///
///  * shows a soft, smaller dot while a mouse or stylus hovers,
///  * springs in to a full ring-and-dot on press,
///  * follows the pointer while it moves,
///  * and fades out on release, or when the pointer leaves [pointers].
///
/// Every animation is finite and comes to rest, so it never keeps
/// `pumpAndSettle` from settling. Animations advance only when the test
/// pumps.
///
/// Reuse it inside your own [SnapVideoSettings.overlay]:
///
/// ```dart
/// overlay: (context, frame) => Stack(
///   children: [
///     const MyWatermark(),
///     SnapPointerOverlay(pointers: frame.pointers),
///   ],
/// ),
/// ```
class SnapPointerOverlay extends StatefulWidget {
  /// Creates an overlay showing [pointers].
  const SnapPointerOverlay({required this.pointers, super.key});

  /// The pointers to show, usually [SnapVideoFrame.pointers].
  final List<SnapPointer> pointers;

  /// A [SnapVideoOverlayBuilder] that shows the frame's pointers.
  ///
  /// ```dart
  /// SnapVideoSettings(overlay: SnapPointerOverlay.builder)
  /// ```
  static Widget builder(BuildContext context, SnapVideoFrame frame) =>
      SnapPointerOverlay(pointers: frame.pointers);

  @override
  State<SnapPointerOverlay> createState() => _SnapPointerOverlayState();
}

class _SnapPointerOverlayState extends State<SnapPointerOverlay> {
  /// Pointers that left [SnapPointerOverlay.pointers] and are fading out.
  final _leaving = <int, SnapPointer>{};

  @override
  void didUpdateWidget(SnapPointerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = {for (final pointer in widget.pointers) pointer.id};
    for (final pointer in oldWidget.pointers) {
      if (!current.contains(pointer.id)) _leaving[pointer.id] = pointer;
    }
    current.forEach(_leaving.remove);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final pointer in widget.pointers)
          _PointerIndicator(
            key: ValueKey(pointer.id),
            pointer: pointer,
            visible: true,
          ),
        for (final pointer in _leaving.values)
          _PointerIndicator(
            key: ValueKey(pointer.id),
            pointer: pointer,
            visible: false,
            onHidden: () => setState(() => _leaving.remove(pointer.id)),
          ),
      ],
    );
  }
}

class _PointerIndicator extends StatefulWidget {
  const _PointerIndicator({
    required this.pointer,
    required this.visible,
    this.onHidden,
    super.key,
  });

  final SnapPointer pointer;
  final bool visible;
  final VoidCallback? onHidden;

  @override
  State<_PointerIndicator> createState() => _PointerIndicatorState();
}

class _PointerIndicatorState extends State<_PointerIndicator>
    with TickerProviderStateMixin {
  /// 0 shows the hover look, 1 the pressed look.
  late final _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );

  /// 0 is hidden, 1 fully shown.
  late final _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 280),
  )..addStatusListener(_onPresenceStatus);

  @override
  void initState() {
    super.initState();
    if (_isPressed || _isLeaving) {
      // A pointer first seen after its release (a quick tap between pumps)
      // still shows its press before fading out.
      _press.value = 1;
    }
    if (_isLeaving) {
      _presence.value = 1;
    }
    _animate();
  }

  @override
  void didUpdateWidget(_PointerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pointer.phase != widget.pointer.phase ||
        oldWidget.visible != widget.visible) {
      _animate();
    }
    if (!widget.visible && _presence.isDismissed) {
      // Already faded out while released, so no status change will follow.
      // The parent cannot rebuild while it is building, so tell it later.
      Future.microtask(() {
        if (mounted) widget.onHidden?.call();
      });
    }
  }

  bool get _isPressed => widget.pointer.phase == SnapPointerPhase.pressed;

  bool get _isLeaving =>
      !widget.visible || widget.pointer.phase == SnapPointerPhase.released;

  void _animate() {
    if (_isLeaving) {
      _presence.animateBack(0, curve: Curves.easeOut);
      return;
    }
    _presence.animateTo(1, curve: Curves.easeOut);
    if (_isPressed) {
      _press.animateTo(1, curve: Curves.easeOutBack);
    } else {
      _press.animateBack(0, curve: Curves.easeOut);
    }
  }

  void _onPresenceStatus(AnimationStatus status) {
    if (status.isDismissed && !widget.visible) widget.onHidden?.call();
  }

  @override
  void dispose() {
    _press.dispose();
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IndicatorPainter(
        position: widget.pointer.position,
        press: _press,
        presence: _presence,
        leaving: _isLeaving,
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.position,
    required this.press,
    required this.presence,
    required this.leaving,
  }) : super(repaint: Listenable.merge([press, presence]));

  final Offset position;
  final Animation<double> press;
  final Animation<double> presence;
  final bool leaving;

  static const _hoverRadius = 8.0;
  static const _pressedRadius = 14.0;
  // A translucent dark dot with a light rim reads on light and dark UIs.
  static const _hoverFill = Color(0x59000000);
  static const _pressedFill = Color(0xB3FFFFFF);
  static const _hoverRing = Color(0xB3FFFFFF);
  static const _pressedRing = Color(0xB3000000);

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = presence.value.clamp(0.0, 1.0);
    if (opacity == 0) return;
    final t = press.value;
    // Grows a little while fading out, and scales up into place on appear.
    final scale = leaving ? 1 + (1 - opacity) * 0.35 : 0.6 + 0.4 * opacity;
    final radius = lerpDouble(_hoverRadius, _pressedRadius, t)! * scale;
    final fill = Color.lerp(_hoverFill, _pressedFill, t.clamp(0.0, 1.0))!;
    final ring = Color.lerp(_hoverRing, _pressedRing, t.clamp(0.0, 1.0))!;
    canvas
      ..drawCircle(
        position,
        radius,
        Paint()..color = fill.withValues(alpha: fill.a * opacity),
      )
      ..drawCircle(
        position,
        radius,
        Paint()
          ..color = ring.withValues(alpha: ring.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lerpDouble(1.5, 2.5, t)!,
      );
  }

  @override
  bool shouldRepaint(_IndicatorPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.leaving != leaving;
}
