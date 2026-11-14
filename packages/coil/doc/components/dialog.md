# Dialog

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/dialog.dart';
```

Exports `CoilDialog`, `CoilDialogFrame`, `CoilDialogKind`, `CoilDialogSize`, `CoilDialogStyle`, `showCoilDialog`.

To change its look or composition, eject a copy into your app with `dart run coil:eject dialog` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## Dialog

- **Anatomy:**
  - header: title (title role), description (body muted), gap 6, 16 below;
  - body;
  - footer: buttons trailing-aligned, gap 8, Cancel before primary;
  - an optional close button (ghost icon-only, 12 from the top and trailing edges).
- **Sizes:** max width `sm` 400 / `lg` 540 / `xl` 880; width = window − 32 up to the max; padding 24; container radius; surface level + 4.
- **Presentation:**
  - Pointer and tablets: centered.
  - **Phone (touch, < 600):**
    - A dialog becomes a **sheet** (§13.3) **only when it contains a form**: the title becomes the sheet title, and the footer becomes the action bar, stacked full-width with the primary on top and Cancel below. `lg` / `xl` forms open at the large detent.
    - **Short confirmations stay centered** (title + a sentence + buttons), the default for dialogs without a form.
    - A dialog shown as a sheet is **always drag-to-dismiss** (`stupid_simple_sheet`'s drag) unless the dialog is non-dismissible, in which case the drag, scrim tap and back are all off.
- **Motion:** scrim on `fade`; panel blur-fade with scale 0.97 → 1 on `gentle`, out on `gentleExit`.
- **Keyboard:** focus is trapped and starts on the first field (or the primary for confirmations). Esc closes. Focus returns to the trigger.
- **Semantics:** a modal route, `scopesRoute`, title as the route name.
- **Do:** use it for decisions that block the flow.
- **Don't:** nest dialogs; open a dialog from a sheet on a phone (push inside the sheet instead).
