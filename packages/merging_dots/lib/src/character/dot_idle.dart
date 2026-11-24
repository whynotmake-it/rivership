import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:motor/motor.dart';

/// Something a `DotCharacter` does on its own while in a state, on top of
/// the state's animation: breathing, blinking, looking around.
///
/// Idles move whole layers of the scene, see `SceneLayer`. They fade in
/// when a state that has them starts and fade out when it ends, so they
/// never jump.
@immutable
sealed class DotIdle {
  const DotIdle();

  /// Slowly grows and shrinks the dots of [layers] by [amount], once every
  /// [period].
  const factory DotIdle.breathe({
    List<int> layers,
    double amount,
    Duration period,
  }) = BreatheIdle;

  /// Gently floats [layers] up and down by [amount] canvas units, once
  /// every [period]. Without [layers], the whole character floats.
  const factory DotIdle.bob({
    List<int>? layers,
    double amount,
    Duration period,
  }) = BobIdle;

  /// Blinks [layer] about every [interval], squashing it to [closed] of its
  /// height. Sometimes blinks twice.
  const factory DotIdle.blink({
    int layer,
    Duration interval,
    double closed,
  }) = BlinkIdle;

  /// Moves [layers] to a new spot within [range] about every [interval],
  /// with [motion], like eyes looking around. Now and then it looks back
  /// to the middle.
  ///
  /// With a [turn], the whole character also turns its head that far
  /// toward each spot, in radians, see `SceneLayer.turn`: the eyes slide
  /// over its face with parallax.
  ///
  /// `DotCharacterController.lookAt` points it somewhere instead.
  const factory DotIdle.lookAround({
    List<int> layers,
    Offset range,
    Duration interval,
    Motion motion,
    Offset turn,
    List<int>? turnLayers,
  }) = LookAroundIdle;
}

/// See [DotIdle.breathe].
final class BreatheIdle extends DotIdle {
  /// See [DotIdle.breathe].
  const BreatheIdle({
    this.layers = const [0],
    this.amount = 0.025,
    this.period = const Duration(milliseconds: 3400),
  });

  /// The layers that breathe.
  final List<int> layers;

  /// How much the dots grow, as a fraction of their radius.
  final double amount;

  /// How long one breath takes.
  final Duration period;

  @override
  bool operator ==(Object other) =>
      other is BreatheIdle &&
      listEquals(other.layers, layers) &&
      other.amount == amount &&
      other.period == period;

  @override
  int get hashCode => Object.hash(Object.hashAll(layers), amount, period);
}

/// See [DotIdle.bob].
final class BobIdle extends DotIdle {
  /// See [DotIdle.bob].
  const BobIdle({
    this.layers,
    this.amount = 1.5,
    this.period = const Duration(milliseconds: 2800),
  });

  /// The layers that float, or null for all of them.
  final List<int>? layers;

  /// How far they float up and down, in canvas units.
  final double amount;

  /// How long one float takes.
  final Duration period;

  @override
  bool operator ==(Object other) =>
      other is BobIdle &&
      listEquals(other.layers, layers) &&
      other.amount == amount &&
      other.period == period;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(layers ?? const []), amount, period);
}

/// See [DotIdle.blink].
final class BlinkIdle extends DotIdle {
  /// See [DotIdle.blink].
  const BlinkIdle({
    this.layer = 1,
    this.interval = const Duration(milliseconds: 3600),
    this.closed = 0.08,
  });

  /// The layer that blinks.
  final int layer;

  /// About how long between blinks.
  final Duration interval;

  /// How much of its height the layer keeps when closed.
  final double closed;

  @override
  bool operator ==(Object other) =>
      other is BlinkIdle &&
      other.layer == layer &&
      other.interval == interval &&
      other.closed == closed;

  @override
  int get hashCode => Object.hash(layer, interval, closed);
}

/// See [DotIdle.lookAround].
final class LookAroundIdle extends DotIdle {
  /// See [DotIdle.lookAround].
  const LookAroundIdle({
    this.layers = const [1],
    this.range = const Offset(8, 5),
    this.interval = const Duration(milliseconds: 2400),
    this.motion = const CupertinoMotion(
      duration: Duration(milliseconds: 420),
      bounce: 0.15,
    ),
    this.turn = Offset.zero,
    this.turnLayers,
  });

  /// The layers that move.
  final List<int> layers;

  /// How far the head turns toward the edge of [range], in radians: `dx`
  /// to the sides, `dy` up and down.
  final Offset turn;

  /// The layers that turn, or null for all of them.
  final List<int>? turnLayers;

  /// How far they move from the middle, in canvas units.
  final Offset range;

  /// About how long they rest on a spot.
  final Duration interval;

  /// How they move to the next spot.
  final Motion motion;

  @override
  bool operator ==(Object other) =>
      other is LookAroundIdle &&
      listEquals(other.layers, layers) &&
      other.range == range &&
      other.interval == interval &&
      other.motion == motion &&
      other.turn == turn &&
      listEquals(other.turnLayers, turnLayers);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(layers),
    range,
    interval,
    motion,
    turn,
    Object.hashAll(turnLayers ?? const []),
  );
}
