# Web reference screenshots

Captured from the live docs site https://www.fluidfunctionalism.com with
Playwright 1.64 (Chromium rev 1248), viewport 1280x900, **deviceScaleFactor 2**
(so every PNG is 2x CSS pixels), by `../../../tool/capture_web_reference.mjs`.
Captured 2026-11-13.

Each file exists twice: `<name>__light.png` and `<name>__dark.png`. Theme is forced
with the site's `ff_theme` cookie plus `prefers-color-scheme` emulation. All other
site settings are at their defaults (Base UI primitives, sharp radius, blue accent
`#6B97FF`, Untitled UI icons, default size), except the `button__compact_*` files,
which use the `ff_size=compact` cookie.

Each image is the demo area (`[data-preview-stage]`) of a ComponentPreview, without
the Preview/Code header, unless noted otherwise. "Hover" means the mouse rests on
the element, "pressed" means `mouse.down()` with no release, and "focus" means
keyboard focus via Shift+Tab/Tab, so `:focus-visible` applies.

`measurements.json` has the computed styles (size, colors, border, box-shadow,
outline, radius, font, padding, transform) of the element and its direct children,
sampled in each state, keyed by theme.

## Button (`/docs/button`)

| File | Shows |
| --- | --- |
| `button__playground_primary` | Playground section, primary "Get started", default size |
| `button__playground_icon_only` | Playground with "Icon only" turned on: `size="icon"` (36x36) |
| `button__variants` | Variants section: inline row primary/secondary/tertiary/ghost/destructive("Delete"), then the same as full width |
| `button__hover_primary` / `_secondary` / `_ghost` | Variants grid with that inline button hovered |
| `button__pressed_primary` / `_secondary` / `_ghost` | Variants grid with that inline button held down |
| `button__focus_primary` | Variants grid with the inline Primary keyboard-focused |
| `button__icons` | With Icons section: Create (leading +), Next (trailing arrow, secondary), Search (tertiary, both icons) |
| `button__loading_disabled` | Loading & Disabled section: "Click me" (idle), secondary loading "Saving" (spinner only; animation frozen), primary disabled |
| `button__compact_playground_primary` | Playground at compact size (28px) |
| `button__compact_playground_icon_only` | Playground, compact + Icon only: `size="icon-compact"` (28x28) |
| `button__compact_variants` | Variants section at compact size |
| `button__compact_icons` | With Icons section at compact size |

## Switch (`/docs/switch`)

| File | Shows |
| --- | --- |
| `switch__off` | "Notifications" switch, off |
| `switch__off_hover` | off, hovered (thumb widens to 18px) |
| `switch__off_pressed` | off, held down (thumb squishes to 20x12) |
| `switch__on` | on (after the click) |
| `switch__on_hover` | on, hovered |
| `switch__on_focus` | on, keyboard focus (ring) |
| `switch__disabled` | Disabled section: "Disabled option", off + disabled |

## Checkbox (`/docs/checkbox`)

| File | Shows |
| --- | --- |
| `checkbox__unchecked` | Basic: "Accept terms and conditions", unchecked |
| `checkbox__unchecked_hover` | unchecked, hovered |
| `checkbox__unchecked_pressed` | unchecked, held down |
| `checkbox__checked` | checked (after the click) |
| `checkbox__checked_focus` | checked, keyboard focus |
| `checkbox__with_description_checked` | "Product updates" + description, checked |
| `checkbox__invalid_and_disabled` | invalid unchecked + error text, and checked + disabled |

The site has no indeterminate checkbox demo, so there is no indeterminate image.

## Tabs (`/docs/tabs`)

| File | Shows |
| --- | --- |
| `tabs__basic` | Basic: Teamspaces/Recents/Favorites/Shared, first selected, with panel text |
| `tabs__icons` | With Icons, first selected |
| `tabs__active_label` | Active Label variant (only the active tab shows its label), first selected |
| `tabs__basic_hover_second` | Basic, "Recents" hovered (hover highlight next to the selected indicator) |
| `tabs__basic_pressed_third` | Basic, "Favorites" held down |
| `tabs__basic_third_selected` | Basic, "Favorites" selected (the indicator has finished sliding) |
| `tabs__basic_focus` | Basic, "Favorites" selected and keyboard-focused |
| `tabs__active_label_second_selected` | Active Label with the second tab selected |

## Input (`/docs/input`)

| File | Shows |
| --- | --- |
| `input__placeholder` | Basic: empty, placeholder "you@company.com" |
| `input__hover` | Basic, hovered |
| `input__focused_empty` | Basic, keyboard focus, empty (caret hidden) |
| `input__focused_filled` | Basic, focus, value "ada@lovelace.dev" |
| `input__filled` | Basic, filled, blurred |
| `input__with_field` | With Field: label "Username", placeholder "ada", description |
| `input__invalid` | Invalid: label, value "ada@anthropic", error text |
| `input__disabled` | Disabled: placeholder "Read-only workspace" |
| `input__types` | Types: password, number (with stepper), file |

## Fluid hover (`/docs/fluid-hover`)

| File | Shows |
| --- | --- |
| `fluid_hover__list_rest` | "Blink or glide" demo: left list uses plain `:hover`, right list uses fluid hover; nothing hovered |
| `fluid_hover__plain_hover_drafts` | the same, "Drafts" hovered in the left (plain `:hover`) list |
| `fluid_hover__list_hover_drafts` | the same, "Drafts" hovered in the right (fluid) list: the highlight is visible |
| `fluid_hover__list_hover_archive` | right list, the highlight has glided to "Archive" |
| `fluid_hover__list_pressed_archive` | right list, "Archive" held down |
| `fluid_hover__three_axes_hover_x` | "3 axes" demo, "Recents" in the x tab strip hovered |
| `fluid_hover__three_axes_hover_y` | "3 axes" demo, "Drafts" in the y list hovered |

## Sizes (`/docs/sizes`)

| File | Shows |
| --- | --- |
| `sizes__default_vs_compact_toolbar` | "The principle": the same toolbar at Default (36px) and Compact (28px), with height callouts |
| `sizes__compact_region_compact` | "Compact regions" frame (header included), Compact selected: buttons and a menu frozen open |
| `sizes__compact_region_default` | the same frame with Default selected |
