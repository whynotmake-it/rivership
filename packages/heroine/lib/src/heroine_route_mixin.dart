import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';

/// A [PageRoute] that supports keeping track of a [Heroine] dismiss gesture.
///
/// Can be used to rebuild any widgets it contains to respond to the dismiss
/// gesture.
/// One common use-case could be to fade out a [Scaffold]'s background.
///
/// You might want to make sure the route you apply this to is not [opaque], so
/// that the route below is visible during the dismiss gesture.
///
/// See [ReactToHeroineDismiss] for a widget that can be used to react to
/// the dismiss gesture.
abstract class HeroinePageRoute<T> extends PageRoute<T> {
  /// A [ValueListenable] that emits the progress of the dismiss gesture.
  ValueListenable<double> get dismissProgress;

  /// A [ValueListenable] that emits the offset of a dismiss gesture.
  ValueListenable<Offset> get dismissOffset;

  /// Updates the dismiss progress of this route.
  void updateDismiss(double progress, Offset offset);

  /// Informs this route that the dismiss gesture has been cancelled.
  void cancelDismiss();

  /// Returns the [HeroinePageRoute] of the given context, if any.
  static HeroinePageRoute<T>? maybeOf<T>(BuildContext context) =>
      switch (ModalRoute.of(context)) {
        final HeroinePageRoute<T> route => route,
        _ => null,
      };
}

/// A mixin that can turn any [PageRoute] into a [HeroinePageRoute].
///
/// This will not automatically rebuild the page when the dismiss progress
/// changes.
///
/// It will also make the route non-opaque, so that the route below is visible
/// during the dismiss gesture.
///
/// This is not supported for default [MaterialPageRoute]s and
/// [CupertinoPageRoute]s, as they need to be opaque.
///
/// Check out this package's example to see how you can build a custom
/// [CupertinoPageRoute] that supports this mixin.
mixin HeroinePageRouteMixin<T> on PageRoute<T> implements HeroinePageRoute<T> {
  final _dismissProgress = ValueNotifier<double>(0);
  final _dismissOffset = ValueNotifier<Offset>(Offset.zero);

  @override
  bool get opaque => false;

  @override
  ValueListenable<double> get dismissProgress => _dismissProgress;

  @override
  ValueListenable<Offset> get dismissOffset => _dismissOffset;

  @override
  void updateDismiss(double progress, Offset offset) {
    _dismissProgress.value = progress.clamp(0, 1);
    _dismissOffset.value = offset;
  }

  @override
  void cancelDismiss() {
    _dismissProgress.value = 0;
    _dismissOffset.value = Offset.zero;
  }
}

/// A widget that can be used to react to a [HeroinePageRoute] dismiss
/// gesture.
///
/// This widget will rebuild when the dismiss gesture progresses.
///
/// If the route this widget is in is not a [HeroinePageRoute], it will not
/// rebuild and build with `dismissProgress` and `dismissOffset` set to 0 and
/// `Offset.zero` respectively.
class ReactToHeroineDismiss extends StatelessWidget {
  /// Creates a new [ReactToHeroineDismiss].
  const ReactToHeroineDismiss({
    required this.builder,
    this.child,
    super.key,
  });

  /// The builder that will be called when the dismiss gesture progresses.
  final Widget Function(
    BuildContext context,
    double progress,
    Offset offset,
    Widget? child,
  ) builder;

  /// The child widget to pass to the [builder].
  ///
  /// {@macro flutter.widgets.transitions.ListenableBuilder.optimizations}
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dismissProgress =
        HeroinePageRoute.maybeOf<dynamic>(context)?.dismissProgress;
    final dismissOffset =
        HeroinePageRoute.maybeOf<dynamic>(context)?.dismissOffset;

    return ListenableBuilder(
      listenable: Listenable.merge([
        dismissOffset,
        dismissProgress,
      ]),
      builder: (context, child) => builder(
        context,
        dismissProgress?.value ?? 0,
        dismissOffset?.value ?? Offset.zero,
        child,
      ),
      child: child,
    );
  }
}
