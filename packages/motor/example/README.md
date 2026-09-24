# Motor example

Seven short chapters that each teach one thing about Motor, with one
interaction each. They are meant to be read in order.

| Chapter | Try this | What it shows |
|---|---|---|
| **01 Retarget** | Tap the tabs quickly, then switch to Curve. | Interrupting a spring keeps its velocity; a curve stalls at every change. |
| **02 Throw** | Fling the video window. | A drag's release velocity carries into a 2D spring, one axis at a time. `FrictionMotion.project` picks the corner. |
| **03 Tracks** | Open the menu, then tap again mid-morph. | Five tracks on one `TrackController`, each with its own motion. |
| **04 Steps** | Ping the notification. | Step lists: `.to`, `.hold`, a wiggle, and `.at` keyframes that land on time. |
| **05 Sync** | Deal the cards, then switch to "On landing". | `.sync(token:)` barriers, and how the token decides who waits for whom. |
| **06 Phases** | Jump between Mini, Card and Full, or autoplay. | `PhaseTrackController` walking named states with barriers between them. |
| **07 Scrub** | Send, then drag the scrubber. | `pause`, `scrubTo` and `resume` on a choreography with springs and a barrier. |

Most chapters show their controller's tracks as live timeline lanes under the
stage. The home screen has a DevTools switch for the in-app inspector from
`motor_devtools`.

## Run the app

From this directory:

```sh
flutter run
```

To build without the devtools:

```sh
flutter run --dart-define=MOTOR_DEVTOOLS=false
```

See the [Motor README](../README.md) for installation and API documentation.

## Code layout

- `lib/chapters.dart` lists the chapters in order. Routes, the home screen and
  the "next" buttons all come from it.
- `lib/pages/` has one file per chapter.
- `lib/widgets/chapter_page.dart` is the layout every chapter shares.
- `lib/widgets/live_timeline.dart` draws a controller's tracks as lanes.

The fonts are Archivo and JetBrains Mono, both under the SIL Open Font License
(see `lib/font_licenses.dart`).
