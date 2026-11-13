# fluid_functionalism (spike)

A Flutter port of [Fluid Functionalism](https://www.fluidfunctionalism.com)
built on [Motor](../motor). This is a spike to show UI direction, not a
published package.

## What's here

| Layer | Files |
| --- | --- |
| Foundations | `FluidTheme` / `FluidThemeData`, `FluidColors` (light + dark from `globals.css`), `FluidColorMix.oklab` (CSS `color-mix(in oklab)`), `FluidSizes` + `FluidSizeScope` (desktop/touch tiers × regular/compact density), `FluidMotion` (Motor `Motion` tokens from `springs.ts`), `FluidTypography` (bundled Inter variable, wght/opsz pairs) |
| Primitives | `FluidPressable` (hover / `:focus-visible` / pressed / disabled as `WidgetState`s), `FluidFocusRing`, `FluidHoverRegion` + `FluidHoverItem` + `FluidHighlight` (the gliding highlight), `FluidIcon` (small stroke icon set) |
| Components | `FluidButton`, `FluidSwitch`, `FluidCheckbox`, `FluidTabs`, `FluidInput` |

Components import only `src/foundation`, `src/primitives` and `src/icons`,
so any component file can be copied ("ejected") into an app together with
those public foundations.

## Sizes

| | control | hit target | body / field text |
| --- | --- | --- | --- |
| desktop | 36 | 36 | 13/20 |
| desktop compact | 28 | 28 | 12/18 |
| touch | 44 | 44 | 15/22, field 16 |
| touch compact | 36 | 44 (padded) | 14/20, field 16 |

The tier defaults from `defaultTargetPlatform` and can be pinned with
`FluidThemeData(tier:)` or `FluidSizeScope(tier:, density:)`.

## Goldens

`flutter test` in this package. Sheets are in `test/goldens/`, the web
references (Playwright, deviceScaleFactor 2) in
`test/goldens/web_reference/` with a README and `measurements.json`.
`tool/capture_web_reference.mjs` recaptures them.

Inter is © The Inter Project Authors, SIL Open Font License 1.1.
`LICENSE.fluid-functionalism` is the upstream design system's MIT license.
