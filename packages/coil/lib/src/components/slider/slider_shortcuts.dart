// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Moves a slider by [steps] steps, or by a page when [page] is set.
class SliderStepIntent extends Intent {
  const SliderStepIntent(this.steps, {this.page = false});

  /// Signed: positive raises the value.
  final int steps;

  /// Whether to move 10 % instead of one step.
  final bool page;
}

/// Moves a slider to its minimum or maximum.
class SliderEndIntent extends Intent {
  const SliderEndIntent({required this.max});

  final bool max;
}

/// Turns the focused thumb's value text into a field.
class SliderEditIntent extends Intent {
  const SliderEditIntent();
}

/// Leaves the value field without changing the value.
class SliderCancelEditIntent extends Intent {
  const SliderCancelEditIntent();
}

const _up = SliderStepIntent(1);
const _down = SliderStepIntent(-1);
const _pageUp = SliderStepIntent(1, page: true);
const _pageDown = SliderStepIntent(-1, page: true);

/// The slider's key bindings. Left and right follow the reading direction.
/// With [edit], Enter opens the value field.
Map<ShortcutActivator, Intent> sliderShortcuts({
  required bool rtl,
  bool edit = false,
}) {
  final forward = rtl
      ? LogicalKeyboardKey.arrowLeft
      : LogicalKeyboardKey.arrowRight;
  final back = rtl
      ? LogicalKeyboardKey.arrowRight
      : LogicalKeyboardKey.arrowLeft;
  return {
    SingleActivator(forward): _up,
    SingleActivator(back): _down,
    const SingleActivator(LogicalKeyboardKey.arrowUp): _up,
    const SingleActivator(LogicalKeyboardKey.arrowDown): _down,
    SingleActivator(forward, shift: true): _pageUp,
    SingleActivator(back, shift: true): _pageDown,
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): _pageUp,
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): _pageDown,
    const SingleActivator(LogicalKeyboardKey.pageUp): _pageUp,
    const SingleActivator(LogicalKeyboardKey.pageDown): _pageDown,
    const SingleActivator(LogicalKeyboardKey.home): const SliderEndIntent(
      max: false,
    ),
    const SingleActivator(LogicalKeyboardKey.end): const SliderEndIntent(
      max: true,
    ),
    if (edit) ...{
      const SingleActivator(LogicalKeyboardKey.enter): const SliderEditIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const SliderEditIntent(),
    },
  };
}

/// The value field's key bindings: Esc leaves without a change. Enter is the
/// field's own submit action.
const sliderFieldShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.escape): SliderCancelEditIntent(),
};
