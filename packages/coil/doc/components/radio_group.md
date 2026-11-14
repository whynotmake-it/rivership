# RadioGroup

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/radio_group.dart';
```

Exports `CoilRadio`, `CoilRadioGroup`, `CoilRadioGroupStyle`, `CoilRadioGroupTrack`, `CoilRadioIndicator`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject radio_group` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## RadioGroup

- **Anatomy:** rows of [radio] label. The radio is a 16 / 14 / 20 / 18 circle, 1.5 px border, with a dot 8 / 7 / 10 / 9.
- **States:**
  - **one selected fill (`active`) glides between rows** on `standard`;
  - the selected label is semibold foreground (with a ghost width);
  - the selected radio's border is transparent and its dot is foreground;
  - hover is the gliding highlight.
- **Motion:** dot in from scale 0.3 + fade on `quick`, out on `fadeExit` (bespoke and short); selected fill `standard`.
- **Keyboard:** roving focus, so the selected row is the tab stop. Arrows move *and* select, with wrapping; Home and End jump.
- **Semantics:** `inMutuallyExclusiveGroup`, `checked`.
- **API:** generic `CoilRadioGroup<T>(value, onChanged, options)`.
- **Other layouts** (radio choice cards): `CoilRadioGroup<T>.custom(value, onChanged, child)` with a `CoilRadio(value:)` anywhere in `child`. It is Flutter's `RadioGroup`, so the keyboard model is the rows': the selected radio is the tab stop, arrows select the next enabled radio in reading order with wrapping, and coil adds Home and End. A radio on its own shows its own ring and hover; in a choice card the card takes both.
- **Don't:** use it for more than 7 options (use Select).
