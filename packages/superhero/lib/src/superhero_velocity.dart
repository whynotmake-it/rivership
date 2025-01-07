import 'package:flutter/material.dart';
import 'package:superhero/src/drag_dismissable.dart';
import 'package:superhero/src/superheroes.dart';

/// An inherited widget that can be used to provide a velocity to the next
/// [Superhero] below this widget.
///
/// When a [Superhero] transition starts, the simulation will look for a
/// [SuperheroVelocity] widget above it and use its velocity to animate the
/// transition.
///
/// If you don't insert one, the velocity will be treated as zero, which is fine
/// in most cases, unless you animate the transition from a gesture.
///
/// See the implementation of [DragDismissable] for an example of how to use
/// this.
class SuperheroVelocity extends InheritedWidget {
  /// Creates a new [SuperheroVelocity] widget.
  const SuperheroVelocity({
    required super.child,
    this.velocity = Velocity.zero,
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
