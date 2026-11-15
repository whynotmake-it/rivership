import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// A pose of dots that can be rendered and animated: a `DotGrid` or a
/// `DotCloud`.
///
/// Every dot is described by three numbers, its *channels*. Animating from
/// one state to another interpolates those channels dot by dot, which is
/// what keeps transitions cheap: a frame is a handful of multiply-adds per
/// dot.
abstract interface class DotState {
  /// The number of channels per dot.
  static const int stride = 3;

  /// How many dots this state has.
  int get dotCount;

  /// Writes the channels of every dot to [out], [stride] values per dot.
  ///
  /// [out] holds at least `dotCount * stride` values.
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
