# Motor example

Seven short chapters that each teach one thing about Motor, with one
interaction each. They are meant to be read in order.

| Chapter | Try this | What it shows |
|---|---|---|
| **01 Toggle** | Tap the switch, or drag it and let go. Tap the heart. | One `TrackController` animates the thumb, its squish and the tint; the drag's tracked velocity carries into the spring. |
| **02 Retarget** | Tap the tabs quickly, then switch to Curve. | Interrupting a spring keeps its velocity; a curve stalls at every change. |
| **03 Fling** | Throw the top postcard. | Letting go turns the gesture into a sequence: a `.free` coast with the throw's velocity, then a spring back under the stack. |
| **04 Steps** | Ping the notification. | Step lists and `.at` keyframes that land exactly on time. |
| **05 Sync** | Deal the cards, then switch to "On landing". | `.sync(token:)` barriers, and how the token decides who waits for whom. |
| **06 Phases** | Drag the player, even during autoplay. | A drag sets every track; the release hands back to the phase timeline at the finger's speed. |
| **07 Scrub** | Send, then drag the scrubber. | `pause`, `scrubTo` and `resume` on a choreography with springs and a barrier. |

Most chapters show their controller's tracks as live timeline lanes under the
stage. The home screen has a DevTools switch for the in-app inspector from
`motor_devtools`.

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

See the [Motor README](../README.md) for installation and API documentation.

## Code layout

- `lib/chapters.dart` lists the chapters in order. Routes, the home screen and
  the "next" buttons all come from it.
- `lib/pages/` has one file per chapter.
- `lib/widgets/chapter_page.dart` is the layout every chapter shares.
- `lib/widgets/live_timeline.dart` draws a controller's tracks as lanes with
  `MotorTimeline` from `motor_devtools`.

The fonts are Archivo and JetBrains Mono, both under the SIL Open Font License
(see `lib/font_licenses.dart`).
