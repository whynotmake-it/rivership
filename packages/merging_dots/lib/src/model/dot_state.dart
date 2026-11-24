import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// A pose of dots that can be rendered and animated: a `DotGrid` or a
/// `DotCloud`.
///
/// Every dot is described by a few numbers, its [channels]. Animating from
/// one state to another interpolates those channels dot by dot, which is
/// what keeps transitions cheap: a frame is a handful of multiply-adds per
/// dot.
abstract interface class DotState {
  /// The number of channels of a grid or cloud dot.
  static const int stride = 3;

  /// The number of channels per dot. States can only animate to states
  /// with as many channels.
  int get channels;

  /// The channel that holds a dot's size. Dots that appear grow from zero
  /// on it, and dots that disappear shrink to zero.
  int get sizeChannel;

  /// How many dots this state has.
  int get dotCount;

  /// Writes the channels of every dot to [out], [channels] values per dot.
  ///
  /// [out] holds at least `dotCount * channels` values.
  void writeChannels(Float32List out);

  /// The position of dot [index], normalized to `0..1` in both axes.
  ///
  /// Staggers use it to delay dots by where they are.
  Offset normalizedPosition(int index);

  /// Whether this state can animate to [other] dot by dot.
  ///
  /// Grids of different sizes can't, so a change in size jumps.
  bool canAnimateTo(DotState other);
}
