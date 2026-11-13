# Component checklist

Every new coil component satisfies all of this before its branch merges.
Read [`DESIGN.md`](../DESIGN.md) (the target spec) and
[`api_guide.md`](api_guide.md) (names and API shape) first. Use an
existing component (`select`, `switch`, `tabs`) as the worked example.

## 1. Files and layout

- `lib/src/components/<name>/<name>.dart`: the widget(s).
- `lib/src/components/<name>/<name>_style.dart`: the style class.
- Private helpers stay in the component's own folder.
- `lib/<name>.dart` is the public library. It exports the widget and its
  style, and is added to `lib/coil.dart`.
- Imports:
  - only `package:coil/foundation.dart`, `package:coil/primitives.dart`,
    other components' public libraries, Flutter's widgets layer, `motor`
    and `motor_widgets`;
  - never another component's `src/`;
  - `test/architecture/import_rules_test.dart` enforces this.
- Primitives:
  - a new primitive goes in a new file under `lib/src/primitives/` only when
    two or more components need it;
  - changes to an existing primitive are reported to the orchestrator, not
    made inside a wave.

## 2. API

- Names follow api_guide §2 ("same idea, same name").
  - Value controls: `value` / `values` + `onChanged`; a null callback
    disables.
  - Collections are generic in `T` and report values, never indexes. Data
    entries use `CoilOption<T>` (or a `Coil<Name>Item<T>` with `value`,
    `label`, `child`).
- Enums over booleans; `Widget?` slots over `showX` flags.
- Every component takes `size:`, `motion:`, `style:` and, if it has
  focusable parts, `focusNode`/`autofocus`.
- Overlays take `presentation:` and `controller: CoilPopupController?`.
  They wrap their trigger in `CoilAdaptivePopup` and close with a
  `CoilPopupCloseReason`.

## 3. Style class

- Read sizes with `CoilTheme.metricsOf`, never from built-in constants.
- `Coil<Name>Style extends CoilComponentStyle<Coil<Name>Style>`:
  - nullable fields;
  - `factory .fallback(CoilThemeData theme, CoilMetrics metrics, …)` that
    derives every field from tokens;
  - `merge` (other side wins; text styles merge);
  - `props`.
- State colors are `WidgetStateProperty<Color?>`. The doc comment lists
  which states it resolves.
- The component resolves
  `fallback(...).merge(CoilTheme.styleOf<S>(context)).merge(widget.style)`
  and reads colors, radii, text styles and sizes only from the result.
- Styles hold look only, never behavior or motion.

## 4. Motion

- All motion goes through `CoilTheme.motionOf(context, override:
  widget.motion)`, read where each animation starts. Opacity and color use
  `fade`/`fadeExit`; travel uses `quick`/`standard`/`gentle` and their
  exits.
- **Several animated parts → a typed track class.**
  - Declare `final class Coil<Name>Track<T extends Object> extends
    Track<T>` with a private constructor and `static final` tracks (with
    `debugLabel`s) on it.
  - Take `motions: Map<Coil<Name>Track<Object>, Motion>?`.
  - Resolve each track with `CoilTheme.trackMotionOf`, which applies
    instance, then theme `trackMotions`, then the token.
- No `AnimationController`, `Tween` or implicit `Animated*`. Use
  `motor_widgets` for in-place switches and size changes, and `CoilBlurFade`
  for enter/exit. Give `debugLabel`s and wrap internals in
  `MotorInspectionScope(group: 'Coil<Name>')`.

## 5. Interaction

- States come from `CoilInteraction` / `CoilInteractionDetector`:
  - hover only from hover-capable pointers;
  - press with the minimum visibility;
  - the focus ring only after keyboard use.
- Lists use `CoilActiveItemController`, `CoilRovingFocus`, `CoilTypeahead`
  and the motion layer (`CoilHoverRegion` + `CoilHoverHighlight`, highlight and selection
  painters).
- No `MouseRegion`, `onTapDown`, `HapticFeedback`, `highlightMode`,
  `OverlayPortal`, `PopupRoute` or raw Motor controllers for travel in the
  component file.

## 6. Shapes and icons

- **Superellipses only:**
  - `ShapeDecoration` + `RoundedSuperellipseBorder`, `ClipRSuperellipse`,
    `drawRSuperellipse`;
  - pills use radius = height / 2;
  - nested radii are concentric (inner = outer − inset);
  - the architecture test fails on rounded rects.
- **Icons scale with text:**
  - every `IconThemeData` sets `applyTextScaling: true`;
  - drawn glyphs size with `CoilIconSize.of(context)`;
  - boxes that are glyph-like (checkbox, radio) scale with the `TextScaler`;
  - gaps don't scale.
- Heights are minimums (`pad + line box + pad`), never fixed.
- No bundled icons: slots take any widget.

## 7. Tests (all required)

- **Goldens across the matrix:** add a story to `_stories` in
  `test/golden_matrix_test.dart`. That covers light/dark × pointer/touch ×
  text scale 1/1.5/2, RTL and high contrast. Overlays also get open-state
  goldens for popover and sheet, light and dark. Look at every golden
  before committing it.
- **Ink centering:** add each label-bearing variant to the `cases` map in
  `test/label_alignment_test.dart` (±1 px at every tier, size and text
  scale).
- **Pattern:** add the component to `test/patterns_test.dart` with
  `expectCoilPattern`, in LTR and RTL. Add a `CoilPattern` value in
  `test/src/coil_pattern.dart` if no existing one fits.
- **No sticky states:** a touch leaves no hover and a click shows no ring
  (extend `test/touch_vs_mouse_test.dart`).
- **IME:** components hosting text get composing-guard tests (see
  `test/text_field_core_ime_test.dart`).
- **Motion:** reduced motion makes travel instant; a runtime theme change
  applies to the next animation.
- **Style:** fallback < theme override < instance, as in
  `test/style_test.dart`.
- Run with Flutter 3.47:
  - `dart analyze --fatal-infos` clean;
  - `flutter test` green.

## 8. DESIGN.md compliance

- Sizes, states, motion tokens, keyboard and semantics match the
  component's DESIGN.md §14 entry. Where they can't or shouldn't, update
  DESIGN.md in the same change and say why in the commit.
- Semantics: the role, states (`checked`, `selected`, `expanded`,
  `toggled`, …), a label, and live regions where DESIGN.md says so.

## 9. No workarounds

Idiomatic Flutter or report the gap:

- no text-metric hacks;
- nothing wrapping `EditableText`'s paint transform;
- no post-layout measuring followed by a rebuild;
- no compensation layers that hide a wrong result.

If the idiomatic way can't produce the result, stop and report it with
evidence (a golden, `file:line` in the Flutter source).
