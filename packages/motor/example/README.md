# Motor example

Motor's interactive gallery, built with [coil](../../coil), the repository's
design system. Each demo shows one Motor idea, the call it is making, and
for most a live timeline of its tracks.

[Open Example](https://whynotmake-it.github.io/rivership/#/motor)

## Run the app

The gallery runs inside the repository's example app, which ships web and
macOS targets. From the repository root:

```sh
cd apps/example
flutter run -d chrome
```

To build without the devtools:

```sh
flutter run -d chrome --dart-define=MOTOR_DEVTOOLS=false
```

## Demos

| Section | Demo | What it shows |
|---|---|---|
| Springs | **Spring lab** | Tune a `CupertinoMotion`'s duration and bounce (or pick a curve) and see its response, with the *ended* and *settled* moments. Drag the dot and let go. |
| | **Toggle** | One `TrackController` animates the thumb, its squish and the tint; `set()` follows a drag and `animate()` carries on at its speed. |
| | **Retarget** | A spring and a curve chase the same clicks. Both start from where they are; only the spring keeps its speed. |
| | **Card stack** | A thrown card hands its speed into a two-phase timeline through `initialValues:`. |
| Choreography | **Steps** | Each track runs its own steps, with a different motion per step, `.at` keyframes and a `.sync` barrier. |
| | **Sync** | `.sync(token:)` barriers make tracks wait for each other; the token decides who waits for whom. |
| | **Phases** | A `PhaseTrackBuilder` with named phases you can drag between, even during autoplay. |
| | **Scrub** | `pause`, `scrubTo` and `resume` on a choreography of curves, springs and a barrier. |
| Building blocks | **Converters** | `.offset`, `.colorRgb` and `MotionConverter.angle`: every dimension on its own spring. |
| | **Controllers** | `BoundedMotionController`: `forward`, `reverse`, `play` with steps, `stop`, and velocity tracking. |
| | **Tick rates** | The same loop at different `tickerRate`s with `fixed_ticker`. |
| Widgets | **Implicit widgets** | `MotionSizeSwitcher`, `MotionContainer` and `MotionSize` from `motor_widgets`. |
| | **Drag and drop** | A list reordered with `MotionReorderable` and `MotionDraggable`. |
| Tools | **DevTools** | `motor_devtools`, the in-app timeline. The sidebar's switch shows it on any page. |

See the [Motor README](../README.md) for installation and API documentation.

## Code layout

- `lib/main.dart` has `motorRoutes`, for mounting the gallery in another app,
  and a standalone `main()`.
- `lib/chapters.dart` lists the demos in order. The sidebar, the overview and
  the "Next" links all come from it.
- `lib/shell/` is the gallery's shell: the coil theme and the sidebar.
- `lib/pages/` has one file per demo.
- `lib/widgets/chapter_page.dart` is the layout every demo shares.

Inside an app that provides a `CoilTheme`, the gallery uses that theme.
Otherwise it follows the platform's brightness, with coil's Allo typography
when the app bundles Allo. Code is set in JetBrains Mono, under the SIL Open
Font License (see `lib/font_licenses.dart`).
