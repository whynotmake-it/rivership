import 'package:flutter/widgets.dart';

/// How far one [CoilSliderStepIntent] step goes.
enum CoilSliderIncrement {
  /// One step: a division, the next listed value, or 1 % without either.
  step,

  /// A page: 10 % of the range, and at least one step.
  page,
}

/// Moves the focused slider thumb by [steps] increments. The arrow keys
/// (a [CoilSliderIncrement.step]) and Shift+arrows, Page Up and Page Down
/// (a [CoilSliderIncrement.page]) map to it.
///
/// `CoilSlider` and `CoilRangeSlider` handle it with a `CoilDefaultAction`,
/// so an [Actions] entry for this intent above the slider replaces what
/// the keys do, for example to snap to values of the app's own:
///
/// ```dart
/// Actions(
///   actions: {
///     CoilSliderStepIntent: CallbackAction<CoilSliderStepIntent>(
///       onInvoke: (intent) => setVolume(volume + intent.steps * 5),
///     ),
///   },
///   child: CoilSlider(value: volume, onChanged: setVolume),
/// )
/// ```
///
/// Screen readers' increase and decrease don't go through it.
class CoilSliderStepIntent extends Intent {
  /// Moves by [steps]; positive raises the value.
  const CoilSliderStepIntent(
    this.steps, {
    this.increment = CoilSliderIncrement.step,
  });

  /// How many increments, signed: positive raises the value.
  final int steps;

  /// How far each increment goes.
  final CoilSliderIncrement increment;
}

/// Which end of the range a [CoilSliderLimitIntent] goes to.
enum CoilSliderLimit {
  /// The minimum: Home.
  min,

  /// The maximum: End.
  max,
}

/// Moves the focused slider thumb to the [limit] of its range. Home and End
/// map to it. Like [CoilSliderStepIntent], an [Actions] entry above the
/// slider replaces it.
class CoilSliderLimitIntent extends Intent {
  /// Moves to [limit].
  const CoilSliderLimitIntent(this.limit);

  /// The end of the range to move to.
  final CoilSliderLimit limit;
}
