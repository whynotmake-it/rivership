import 'package:flutter/foundation.dart';

/// Configures how a `FixedTicker` schedules callbacks.
///
/// Use one of the named constructors:
/// - [TickerRate.vsync] for normal display-refresh-rate ticking
/// - [TickerRate.interval] for fixed-rate ticking at a specific duration
/// - [TickerRate.fps] for fixed-rate ticking at a given frames-per-second
@immutable
sealed class TickerRate {
  /// Creates a [TickerRate].
  const TickerRate();

  /// Normal vsync-driven ticking at the display's refresh rate.
  const factory TickerRate.vsync() = VsyncTickerRate;

  /// Fixed-rate ticking at the given [interval].
  const factory TickerRate.interval(Duration interval) = FixedTickerRate;

  /// Fixed-rate ticking at [fps] frames per second.
  factory TickerRate.fps(double fps) {
    assert(fps > 0, 'fps must be positive, got $fps.');
    return FixedTickerRate(
      Duration(microseconds: (1000000 / fps).round()),
    );
  }

  /// The interval for this rate, or `null` for vsync.
  Duration? get interval;
}

/// Vsync-driven ticking at the display's refresh rate.
final class VsyncTickerRate extends TickerRate {
  /// Creates a vsync ticker rate.
  const VsyncTickerRate();

  @override
  Duration? get interval => null;

  @override
  bool operator ==(Object other) => other is VsyncTickerRate;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Fixed-rate ticking at a specific [interval].
final class FixedTickerRate extends TickerRate {
  /// Creates a fixed ticker rate with the given [interval].
  ///
  /// The [interval] must be positive (greater than [Duration.zero]).
  const FixedTickerRate(this.interval);

  @override
  final Duration interval;

  @override
  bool operator ==(Object other) =>
      other is FixedTickerRate && other.interval == interval;

  @override
  int get hashCode => interval.hashCode;
}
