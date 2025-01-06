import 'package:flutter/material.dart';

class SuperheroVelocity extends InheritedWidget {
  const SuperheroVelocity({
    this.velocity = Velocity.zero,
    required super.child,
    super.key,
  });

  /// The current velocity of the next superhero below this widget.
  final Velocity velocity;

  /// Returns the current velocity of the next superhero below this widget.
  ///
  /// If [listen] is true, the listener will be notified when the velocity
  /// changes.
  static Velocity? of(BuildContext context, {bool listen = true}) {
    return listen
        ? context
                .dependOnInheritedWidgetOfExactType<SuperheroVelocity>()
                ?.velocity ??
            Velocity.zero
        : context
                .getInheritedWidgetOfExactType<SuperheroVelocity>()
                ?.velocity ??
            Velocity.zero;
  }

  @override
  bool updateShouldNotify(SuperheroVelocity oldWidget) {
    return oldWidget.velocity != velocity;
  }
}
