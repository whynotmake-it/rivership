import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stupid_simple_sheet/src/shrink_transition.dart';

/// How close to the top a fully open sheet's top edge has to come before it
/// starts making the sheet or page behind it recede.
///
/// A sheet whose top edge stops further down than this from the highest
/// position a sheet can have leaves what is behind it in place. Within this
/// distance, the receding grows linearly, so a sheet that grows to full height
/// pushes back what is behind it continuously.
@internal
const double kSheetRecedeDistance = 44;

/// The share of the receding a sheet applies to what is behind it, given its
/// fully open [height] and the [maxHeight] a sheet can have.
///
/// 1 for a sheet that reaches the top, 0 for a sheet more than
/// [kSheetRecedeDistance] shorter than that.
@internal
double recedeFactorFor({required double height, required double maxHeight}) {
  if (!maxHeight.isFinite || maxHeight <= 0) return 1;
  final gap = maxHeight - height;
  return (1 - gap / kSheetRecedeDistance).clamp(0.0, 1.0);
}

/// Measures the sheet below it and reports its [recedeFactorFor] to
/// [recedeFactor].
///
/// Place it directly around the sheet's `SheetDismissalTransition`, inside the
/// widget that gives the sheet its maximum height. The fully open height of
/// the sheet is its laid out height, or, for a sheet that shrinks to dismiss,
/// the natural height of its content.
///
/// The value is reported after the frame, since listeners of [recedeFactor]
/// rebuild other routes, which is not allowed during layout.
@internal
class SheetRecedeReporter extends SingleChildRenderObjectWidget {
  /// Creates a [SheetRecedeReporter].
  const SheetRecedeReporter({
    required this.recedeFactor,
    super.key,
    super.child,
  });

  /// Receives the share of receding the measured sheet applies to what is
  /// behind it.
  final ValueNotifier<double> recedeFactor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSheetRecedeReporter(recedeFactor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSheetRecedeReporter renderObject,
  ) {
    renderObject.recedeFactor = recedeFactor;
  }
}

/// The render object of [SheetRecedeReporter].
@internal
class RenderSheetRecedeReporter extends RenderProxyBox {
  /// Creates a [RenderSheetRecedeReporter].
  RenderSheetRecedeReporter(this._recedeFactor);

  /// Receives the share of receding the measured sheet applies to what is
  /// behind it.
  ValueNotifier<double> get recedeFactor => _recedeFactor;
  ValueNotifier<double> _recedeFactor;
  set recedeFactor(ValueNotifier<double> value) {
    if (identical(value, _recedeFactor)) return;
    _recedeFactor = value;
    markNeedsLayout();
  }

  double? _pending;

  @override
  void performLayout() {
    super.performLayout();
    final child = this.child;
    if (child == null) return;
    final height = switch (child) {
      RenderShrinkTransition(:final referenceHeight) => referenceHeight,
      _ => child.size.height,
    };
    _report(
      recedeFactorFor(height: height, maxHeight: constraints.maxHeight),
    );
  }

  void _report(double value) {
    if (value == (_pending ?? _recedeFactor.value)) return;
    final schedule = _pending == null;
    _pending = value;
    if (!schedule) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        final pending = _pending;
        _pending = null;
        if (pending == null || !attached) return;
        _recedeFactor.value = pending;
      })
      ..scheduleFrame();
  }
}

/// An animation whose value is its [parent]'s value times [factor].
@internal
class ScaledAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  /// Creates a [ScaledAnimation].
  ScaledAnimation(this.parent, this.factor);

  @override
  final Animation<double> parent;

  /// The factor to multiply [parent]'s value with.
  final ValueListenable<double> factor;

  @override
  double get value => parent.value * factor.value;

  @override
  void addListener(VoidCallback listener) {
    parent.addListener(listener);
    factor.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    parent.removeListener(listener);
    factor.removeListener(listener);
  }
}

/// Scales an animation by a [ValueListenable].
@internal
extension ScaledAnimationX on Animation<double> {
  /// This animation times [factor], or this animation if [factor] is null.
  Animation<double> scaledBy(ValueListenable<double>? factor) =>
      factor == null ? this : ScaledAnimation(this, factor);
}
