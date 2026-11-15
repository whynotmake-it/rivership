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

- **`CoilInput.multiline`:** the same widget, chrome and style as Input. It grows from 3 lines to 10, then scrolls. Leading and trailing slots sit on the first line.
- **Radius:** the item radius, capped at the `rounded` container radius (12 / 16), so a `pill` shape doesn't make a capsule.
- **Sizes:** min 3 lines and max 10, each plus the vertical pad. The first line aligns with Input text.
- **Motion:** growth is instant; colors on `fade`.
- **Keyboard:** Return inserts a newline. (Composers decide sending; see InputMessage.)
- **Don't:** animate growth (it jitters while typing).

## InputGroup

- **Anatomy:** a column of labeled Inputs sharing one hover scope. The field nearest the pointer gets the `hover` fill; nothing glides.
- **Spacing:** 12 between fields (touch 16). Errors sit under each field.
- **Keyboard:** Tab between fields. A tap anywhere in a field's box focuses its text.
- **Touch:** no hover, only focus states.
