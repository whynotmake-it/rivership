import 'package:flutter/material.dart';
import 'package:heroine/src/drag_dismissable.dart';
import 'package:heroine/src/heroines.dart';

/// An inherited widget that can be used to provide a velocity to the next
/// [Heroine] below this widget.
///
/// When a [Heroine] transition starts, the simulation will look for a
/// [HeroineVelocity] widget above it and use its velocity to animate the
/// transition.
///
/// If you don't insert one, the velocity will be treated as zero, which is fine
/// in most cases, unless you animate the transition from a gesture.
///
/// See the implementation of [DragDismissable] for an example of how to use
/// this.
class HeroineVelocity extends InheritedWidget {
  /// Creates a new [HeroineVelocity] widget.
  const HeroineVelocity({
    required super.child,
    this.velocity = Velocity.zero,
    super.key,
  });

  /// The current velocity of the next [Heroine] below this widget.
  final Velocity velocity;

  /// Returns the current velocity of the next [Heroine] below this widget.
  ///
  /// If [listen] is true, the listener will be notified when the velocity
  /// changes.
  static Velocity? of(BuildContext context, {bool listen = true}) {
    return listen
        ? context
                .dependOnInheritedWidgetOfExactType<HeroineVelocity>()
                ?.velocity ??
            Velocity.zero
        : context.getInheritedWidgetOfExactType<HeroineVelocity>()?.velocity ??
            Velocity.zero;
  }

  @override
  bool updateShouldNotify(HeroineVelocity oldWidget) {
    return oldWidget.velocity != velocity;
  }
}
