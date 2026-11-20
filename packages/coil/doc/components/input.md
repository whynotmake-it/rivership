# Input

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/input.dart';
```

Exports `CoilInput`, `CoilInputGroup`, `CoilInputStyle`, `CoilInputTrack`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject input` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Input

- **Anatomy:** a hairline field → [leading muted icon] text [trailing slot].
- **Sizes:** height = `controlHeight`, padding `controlPaddingX`, field text role.
- **Slots:** placed by measuring them in the same layout pass as the text (`CoilInputSlotPlacement.auto`), so the first frame is right:
  - a slot that fits a line of text (an icon, a "EUR" unit, a spinner, a kbd) sits **inline**: inside the padding, centered on the text;
  - a taller slot (a button) sits **inset**: into the padding, centered, and as far from the side as from the top and bottom, so its corners are concentric with the field's. The field keeps its height while the slot and `slotInset` (4; 2 compact) on each side fit: a 28 compact button in a 36 field, a 36 one in a 44 touch field. In a compact field the compact button takes the height that fits (`CoilInputSlotScope.maxExtent`): 24 in a 28 field, 32 in a 36 touch one, so the field keeps its compact height too. Only a taller slot grows the field, by just enough (a 36 button makes a pointer field 44);
  - a `CoilButton` in a slot defaults to compact and to the nested radius (`CoilInputSlotScope`); an explicit `size:` or `style:` wins. On touch it drops its own hit padding and the field gives taps in a 44 box around it to the button;
  - `leadingPlacement` / `trailingPlacement` override: `inline` keeps today's padding (a button makes the field grow), `inset` tucks even a short slot in.
- **States:**
  - rest: `border`, transparent; hover (pointer): `hover` fill;
  - focus: border `foreground` @ 40 %, hover fill removed (shown for any focus);
  - invalid: `destructive` 50 % (focus wins); disabled: 50 %; read-only: no hover.
- **Number variant:** two stepper buttons inset 4 (2 compact) at the trailing edge, 28 / 24 / 36 visual (44 hit on touch), radius item − 4, muted → foreground on hover. Long-press repeats with acceleration (400 ms, then every 80 ms, then 40 ms). Up and Down step.
- **Motion:** border and fill on `fade`.
- **Platform:** `keyboardType`, `textInputAction`, `autofillHints` and `textCapitalization` per use; autocorrect and suggestions are forced off while obscured; `scrollPadding` clears the keyboard by 16; native selection, magnifier and edit menu.
- **Enter:** single-line Return is the input action (`onSubmitted`); a Return that commits an IME composition only commits.
- **Keyboard:** native editing; IME-safe.
- **Do:** always pair it with a Field label.
- **Don't:** put a focus ring on fields; use the placeholder as the label.

## Textarea

- **`CoilInput.multiline`:** the same widget, chrome and style as Input. It grows from 3 lines to 10, then scrolls. Inline slots sit on the first line; an inset slot (a button) sits in the bottom corner, as far in as it would be in a single-line field, like the composer's send button.
- **Radius:** the item radius, capped at the `rounded` container radius (12 / 16), so a `pill` shape doesn't make a capsule.
- **Sizes:** min 3 lines and max 10, each plus the vertical pad. The first line aligns with Input text.
- **Motion:** growth is instant; colors on `fade`.
- **Keyboard:** Return inserts a newline. (Composers decide sending; see InputMessage.)
- **Don't:** animate growth (it jitters while typing).

## InputGroup

- **Anatomy:** a column of labeled Inputs sharing one hover scope. The field nearest the pointer gets the `hover` fill; nothing glides. Each Input places its slots as Input does, so a button in one doesn't make it taller than its neighbors.
- **Spacing:** 12 between fields (touch 16). Errors sit under each field.
- **Keyboard:** Tab between fields. A tap anywhere in a field's box focuses its text.
- **Touch:** no hover, only focus states.
