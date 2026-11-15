# Slider

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/slider.dart';
```

Exports `CoilRangeSlider`, `CoilRangeValues`, `CoilSlider`, `CoilSliderStyle`, `CoilSliderTrack`, `CoilSliderValueDisplay`, `CoilSliderVariant`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject slider` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Slider

- **Widgets:** `CoilSlider` for one value. `CoilRangeSlider` for two: `values: CoilRangeValues(start, end)`, like Flutter's `RangeSlider`.
- **Value API:** `label` is a widget. The value shows through `valueBuilder` (a widget, default a plain number up to two decimals), screen readers get `semanticFormatter`, and the value field uses `editFormatter` / `editParser`.
- **Anatomy:**
  - **Row** (variants `scrubber`, the default, and `pips`): a full-width bordered row, `controlHeight` tall, with the label at the start and the value at the end (tabular, muted). The fill is `active` and a handle line sits at the value. `pips` adds a 5 px dot per step, left out where the label or value sits. The range spans the row edge to edge: the fill is empty at min and full at max, and the end pips sit under the handle line. The label takes the free space and ellipsizes; the value keeps its reserved width.
  - **Pill** (variant `pill`): an 18 high pill track with a 1 px `border` and a 16 white knob in a 20 box, between the label and the value; fill `selected` 50 % (dark `accent` 40 %). `pillPips` adds a 4 px dot per step (`pip` color), growing 1.25× while hovered on `standard`. Dots under the fill fade out over 2 px past its edge; a range hides those between its thumbs.
  - **Narrow pill rows:** when the label, the value and a 96 px track (`pillMinTrack`) don't fit on one line, the label and value share a line above a full-width track, and the label ellipsizes. The original has no automatic rule: its compact slider takes an explicit `valuePosition` (`left`, `right`, `top`, `bottom`). coil decides during layout, from the row's width and the label's and value's natural widths.
  - **Range:** always the pill (`pill` or `pillPips`), with a knob per thumb and the fill between them. On the row, the two handle lines would land in the label and value text, and the original draws ranges only on the pill. The value text reads `start – end`.
- **Steps:** `divisions` (equal steps) or `steps` (a list of allowed values at any spacing, between `min` and `max`). Never both. Values snap to the nearest step; a value exactly halfway goes to the lower one. Pips sit at each step.
- **Value display** (`valueDisplay`):
  - `text` (default): the value text.
  - `editable`: a click or tap on a value, or Enter on a focused thumb, turns it into a field (the `field` type role, a 1 px `border` underline, as wide as the widest value). It opens with `editFormatter`'s text (the raw number by default) selected and reads it back with `editParser`. Enter or Done applies it, clamped to the range and snapped to a step; leaving the field applies it too. Esc leaves the value unchanged. Text that isn't a number changes nothing. Enter and Esc return focus to the thumb. While the pointer is on the value, the track shows no hover preview.
  - `tooltip`: no value text. A bubble rides each thumb while the slider is hovered, pressed or focused with the keyboard.
- **Sizes:** `size` changes sizes only: the row is `controlHeight` (36 / 28 pointer, 44 / 42 touch) with `controlPaddingX`. On touch the pill's knob is 22 visual, 44 hit.
- **States:** the label and value turn foreground and semibold (with ghost width) while hovered, pressed or focused. Pips: dots at 30 % muted, the one at each thumb foreground. Disabled 50 %.
- **Focus ring:** after keyboard use only. The row rings the whole row, and the focused thumb's handle line goes full foreground. The pill rings the focused knob, as the original does per thumb.
- **Pointer extras:** hover shows a preview bar (`accent` 40 %) that springs on `quick` from the nearest thumb toward the snapped hover value, plus the value bubble (the touch bubble) with the hover value.
  - The bubble appears on the hover at once, with no sideways travel; only its fade plays.
  - Until the preview reaches it, the bubble follows the hover directly while the preview chases.
  - Once they meet (the preview arrives or crosses it), the bubble rides the preview's spring as the hover moves.
- **Touch:** no preview. **A value bubble** (the tooltip look) sits 8 above the track at the press: the value under the pointer, snapped. The bubble belongs to the pointer, so the thumb springs underneath to meet it and the bubble never travels with the spring and fades on `fade` / `fadeExit`. A press on the track jumps the nearest thumb there on the way down, as native sliders do. It happens when the press shows (at once, or after `kPressTimeout` while a drag could still win, as in Flutter's `Slider`). Dragging then sets the value directly with no fling, and a press that becomes a drag reports one change (one `onChangeStart`, one `onChangeEnd`).
- **Range input:** a tap or drag moves the nearest thumb, by touch and by mouse. On two stacked thumbs, the side of the press picks one, and on them the drag's direction does. The thumbs can't cross but may meet.
- **Motion:** thumbs and fill settle on `standard` after a jump, a key or a typed value; follow the finger 1:1 while dragging a continuous slider; with steps they spring to each step and retarget as the pointer crosses steps. Handle and color on `fade`; pip growth `standard`. `CoilSliderTrack.thumb` moves both thumbs of a range.
- **Keyboard:** arrows ±step (a step list walks the list); PageUp/PageDown and Shift+arrow ±10 %, at least one step; Home and End go to min and max, or to the other thumb in a range. A range is two tab stops.
- **Semantics:** `slider` / adjustable, a formatted `value`, increase and decrease actions. A range is a group (the label) with one slider node per thumb, named `startSemanticLabel` and `endSemanticLabel` ("Minimum" and "Maximum" by default). An open value field is its own text-field node.
- **Bubbles:** every value bubble (hover, press and tooltip mode) is a `CoilTooltipAnchor.controlled` with the `CoilTooltipBubble` look, faded in and out on `CoilSliderTrack.bubble`. Its anchor is a knob-wide box as tall as the track, at the bubble's fraction, so the bubble sits 8 above the track and follows the thumb in layout. Bubbles live in the overlay and stay out of semantics; the slider's nodes carry the value.
