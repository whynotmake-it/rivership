# Field

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/field.dart';
```

Exports `CoilChoiceCard`, `CoilChoiceCardStyle`, `CoilChoiceCardTrack`, `CoilField`, `CoilFieldGroup`, `CoilFieldOrientation`, `CoilFieldSeparator`, `CoilFieldSet`, `CoilFieldStyle`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject field` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Field (FieldSet, Legend, Field, Label, Description, Error, Separator, ChoiceCard)

- **Anatomy:** a label (body; muted when stacked, foreground beside a control), the control, a description (caption muted), and an error (caption `destructive` with a 14 alert icon, live region). These are Widget slots, not discovery.
- **Orientation:**
  - `vertical`: gaps 6 and 4 (touch 6 and 6);
  - `horizontal`: label left, control right, `gap`;
  - `responsive`: vertical below 448 of group width, horizontal above.
- **Spacing:** fields 12 apart (touch 16). FieldSet legend: subtitle semibold, 4 below.
- **ChoiceCard:** a checkbox, switch or radio at the start, centered on the title's first line, then the title (body, foreground) and description (caption, muted), in a 1 px `border` container at the container radius. Padding is `controlPaddingX` (12, 10 compact, 16 touch).
  - The whole card is the target. Inside it the control drops its own hit-area padding.
  - Hover (pointer): the `hover` fill, and the control shows its hover look. Touch press: the `active` fill.
  - Selected: border `foreground` 40 %.
  - Keyboard focus rings the whole card (1 px, no offset). The control leaves out its own ring, told by `CoilFieldScope.framed`.
  - Fill and border on `fade` / `fadeExit`. Pass the control's value as `selected`, as with a list tile.
- **Separator:** 20 high with a hairline, optionally with a centered caption label.
- **Required:** a muted ` *` after the label (excluded from semantics) plus the `isRequired` semantics flag.
- **Horizontal:** label and description share the row 1 : 1 with the control, which sits at the trailing edge.
- **Semantics:** one node per field. Label, description and error join the control's label, in that order, so they're read with its role and value. The node carries `isRequired` and `validationResult`, and is a live region while an error shows.
- **Label tap:** runs the control's label action (`CoilFieldControl`): text fields focus, toggles toggle.
- **Toggle rows are one target.** In a horizontal field or a setting row, a tap anywhere in the row (padding, gap, description) toggles a checkbox, switch or radio, as in a native settings list. The control shows hover and press while the row has them, and keeps its own focus ring. Other controls (text fields, selects, sliders, buttons) and rows with several controls respond only on the control; the label still focuses a text field. `CoilFieldRow` does this for any row; a control opts in with `CoilFieldControl.tapArea`.
- **One control per Field.** A group of controls goes in a FieldSet, a container with a header legend.
- **Invalid:** the label turns `destructive`, and the control gets its invalid look.
