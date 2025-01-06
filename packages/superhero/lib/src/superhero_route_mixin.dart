import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract class SuperheroPageRoute<T> extends PageRoute<T> {
  /// A [ValueListenable] that emits the progress of the dismiss gesture.
  ValueListenable<double> get dismissProgress;

  /// Updates the dismiss progress of this route.
  void setDismissProgress(double progress);

  /// Informs this route that the dismiss gesture has been cancelled.
  void cancelDismiss();

  /// Returns the [SuperheroPageRoute] of the given context, if any.
  static SuperheroPageRoute<T>? maybeOf<T>(BuildContext context) =>
      switch (ModalRoute.of(context)) {
        final SuperheroPageRoute<T> route => route,
        _ => null,
      };
}

/// A mixin that can turn any [PageRoute] into a [SuperheroPageRoute].
///
/// This will not automatically rebuild the page when the dismiss progress
/// changes.
mixin SuperheroPageRouteMixin<T> on PageRoute<T>
    implements SuperheroPageRoute<T> {
  final _dismissProgress = ValueNotifier<double>(0);

  @override
  ValueListenable<double> get dismissProgress => _dismissProgress;

  @override
  void setDismissProgress(double progress) {
    _dismissProgress.value = progress.clamp(0, 1);
  }

  @override
  void cancelDismiss() {
    _dismissProgress.value = 0;
  }
}
