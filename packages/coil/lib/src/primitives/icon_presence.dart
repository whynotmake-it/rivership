/// @docImport 'package:coil/src/foundation/theme.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// How present an icon is while a component animates it in or out, for an
/// icon that wants to animate itself.
///
/// Wherever Coil shows an icon that appears, disappears or swaps with
/// another (a checkbox's tick, a select's checkmark, the copy feedback,
/// the composer's send and stop), it wraps the icon in a
/// [CoilIconPresence] carrying [presence]: 0 when the icon is absent, 1
/// when it is fully there. A swap is two presences crossing: the outgoing
/// icon's goes from 1 to 0 while the incoming icon's goes from 0 to 1.
///
/// - An icon that reads [maybeOf] animates itself from it, and Coil leaves
///   it alone: a Lottie with the presence as its controller, or a painter
///   that repaints with it. Coil's own drawn tick works this way.
/// - An icon that doesn't read it gets Coil's fallback: it fades and grows
///   from [absentScale] as the presence rises, and back as it falls.
/// - Outside an animation, [maybeOf] is null and an icon is static.
///
/// ```dart
/// class DrawnCheck extends StatelessWidget {
///   const DrawnCheck({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final presence = CoilIconPresence.maybeOf(context);
///     return CustomPaint(
///       size: Size.square(CoilIconSize.of(context)),
///       painter: CheckPainter(presence, IconTheme.of(context).color!),
///     );
///   }
/// }
///
/// class CheckPainter extends CustomPainter {
///   // Repaints on every tick of the presence, without rebuilding.
///   CheckPainter(this.presence, this.color) : super(repaint: presence);
///
///   final Animation<double>? presence;
///   final Color color;
///
///   @override
///   void paint(Canvas canvas, Size size) {
///     final drawn = presence?.value ?? 1;
///     // Draw `drawn` of the stroke.
///   }
///
///   @override
///   bool shouldRepaint(CheckPainter old) =>
///       old.presence != presence || old.color != color;
/// }
/// ```
///
/// The presence stays within 0 to 1: a spring that overshoots is clamped,
/// and a bounce belongs outside the icon. The [Animation] object stays the
/// same while it runs, so an icon listens to it (an [AnimatedBuilder], a
/// painter's `repaint`) and nothing above rebuilds per frame. Under reduced
/// motion it jumps to its end ([CoilIconSwitcher]).
///
/// The fallback is decided when the icon paints: the icon builds first,
/// and reading [maybeOf] claims the presence for it.
class CoilIconPresence extends InheritedWidget {
  /// Provides [presence] to the icon [child], and fades and scales [child]
  /// with it unless the icon reads [maybeOf].
  CoilIconPresence({
    required Animation<double> presence,
    required Widget child,
    super.key,
  }) : presence = _ClampedAnimation.of(presence),
       super(child: _IconFallback(child: child));

  /// The scale the fallback starts from when the presence is 0.
  static const absentScale = 0.8;

  /// 0 when the icon is absent, 1 when it is fully there; clamped.
  final Animation<double> presence;

  /// The presence of the icon at [context], or null when Coil isn't
  /// animating it.
  ///
  /// Reading it means the icon animates itself: Coil applies no fallback to
  /// it.
  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilIconPresence>()?.presence;

  /// A [MotionSwitcher] or [AnimatedSwitcher] transition that gives each
  /// child its switcher presence, so a swap is two presences crossing.
  static Widget transition(Widget child, Animation<double> animation) =>
      CoilIconPresence(presence: animation, child: child);

  @override
  InheritedElement createElement() => _CoilIconPresenceElement(this);

  @override
  bool updateShouldNotify(CoilIconPresence oldWidget) =>
      oldWidget.presence != presence;
}

class _CoilIconPresenceElement extends InheritedElement {
  _CoilIconPresenceElement(CoilIconPresence super.widget);

  /// Whether something under the icon read the presence.
  final claimed = ValueNotifier(false);

  final _readers = <Element>{};

  @override
  void updateDependencies(Element dependent, Object? aspect) {
    super.updateDependencies(dependent, aspect);
    _readers.add(dependent);
    claimed.value = true;
  }

  @override
  void removeDependent(Element dependent) {
    super.removeDependent(dependent);
    _readers.remove(dependent);
    claimed.value = _readers.isNotEmpty;
  }

  @override
  void unmount() {
    super.unmount();
    claimed.dispose();
  }
}

/// [parent] clamped to 0–1, equal to another wrapper of the same parent so
/// a rebuild doesn't hand icons a new presence.
@immutable
class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  static Animation<double> of(Animation<double> animation) =>
      animation is _ClampedAnimation ? animation : _ClampedAnimation(animation);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is _ClampedAnimation && identical(other.parent, parent);

  @override
  int get hashCode => identityHashCode(parent);
}

/// Coil's fallback for an icon that doesn't read its presence.
class _IconFallback extends SingleChildRenderObjectWidget {
  const _IconFallback({required super.child});

  static _CoilIconPresenceElement _scope(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<CoilIconPresence>()!
          as _CoilIconPresenceElement;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final scope = _scope(context);
    return _RenderIconFallback(
      (scope.widget as CoilIconPresence).presence,
      scope.claimed,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIconFallback renderObject,
  ) {
    final scope = _scope(context);
    renderObject
      ..presence = (scope.widget as CoilIconPresence).presence
      ..claimed = scope.claimed;
  }
}

class _RenderIconFallback extends RenderProxyBox {
  _RenderIconFallback(this._presence, this._claimed);

  Animation<double> _presence;
  Animation<double> get presence => _presence;
  set presence(Animation<double> value) {
    if (value == _presence) return;
    if (attached) {
      _presence.removeListener(_changed);
      value.addListener(_changed);
    }
    _presence = value;
    _changed();
  }

  ValueListenable<bool> _claimed;
  ValueListenable<bool> get claimed => _claimed;
  set claimed(ValueListenable<bool> value) {
    if (identical(value, _claimed)) return;
    if (attached) {
      _claimed.removeListener(_changed);
      value.addListener(_changed);
    }
    _claimed = value;
    _changed();
  }

  /// How much of the fallback shows: 1 when the icon claimed its presence.
  double get _shown => _claimed.value ? 1 : _presence.value;

  bool _partial = false;

  final _transform = LayerHandle<TransformLayer>();

  void _changed() {
    final partial = _shown > 0 && _shown < 1;
    if (partial != _partial) {
      _partial = partial;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _presence.addListener(_changed);
    _claimed.addListener(_changed);
    _partial = _shown > 0 && _shown < 1;
  }

  @override
  void detach() {
    _presence.removeListener(_changed);
    _claimed.removeListener(_changed);
    super.detach();
  }

  @override
  void dispose() {
    _transform.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _partial;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown > 0 && super.hitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final shown = _shown;
    if (child == null || shown <= 0 || shown >= 1) {
      layer = null;
      _transform.layer = null;
      if (child != null && shown > 0) context.paintChild(child, offset);
      return;
    }
    final scale =
        CoilIconPresence.absentScale +
        (1 - CoilIconPresence.absentScale) * shown;
    final center = size.center(Offset.zero);
    final transform = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    layer = context.pushOpacity(
      offset,
      Color.getAlphaFromOpacity(shown),
      (context, offset) {
        _transform.layer = context.pushTransform(
          needsCompositing,
          offset,
          transform,
          super.paint,
          oldLayer: _transform.layer,
        );
      },
      oldLayer: layer as OpacityLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final shown = _shown;
    if (shown > 0 && shown < 1) {
      final scale =
          CoilIconPresence.absentScale +
          (1 - CoilIconPresence.absentScale) * shown;
      final center = size.center(Offset.zero);
      transform
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
    }
    super.applyPaintTransform(child, transform);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('presence', _presence.value))
      ..add(FlagProperty('claimed', value: _claimed.value, ifTrue: 'claimed'));
  }
}

/// Shows an icon and animates it in and out with a [CoilIconPresence]: a
/// new [child] (one with a different key or type) comes in on [motion]
/// while the old one leaves on [exitMotion], two presences crossing; a
/// null [child] lets the icon leave.
///
/// Pass motions from [CoilTheme.motionOf] (and a component's track
/// motions). Under reduced motion every presence jumps to its end.
///
/// ```dart
/// CoilIconSwitcher(
///   motion: motion.fade,
///   exitMotion: motion.fadeExit,
///   child: checked ? const CoilIcon(.check) : null,
/// )
/// ```
class CoilIconSwitcher extends StatelessWidget {
  /// Creates an icon switcher.
  const CoilIconSwitcher({
    required this.motion,
    super.key,
    this.exitMotion,
    this.child,
  });

  /// The icon shown, or null for none.
  ///
  /// Give icons of the same type different keys to swap them.
  final Widget? child;

  /// The spring an incoming icon's presence follows to 1.
  final Motion motion;

  /// The spring an outgoing icon's presence follows to 0.
  ///
  /// Defaults to [motion].
  final Motion? exitMotion;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return MotionSwitcher(
      motion: reduced ? const Motion.instant() : motion,
      exitMotion: reduced ? const Motion.instant() : exitMotion ?? motion,
      transitionBuilder: CoilIconPresence.transition,
      debugLabel: 'CoilIconSwitcher',
      child: child,
    );
  }
}
