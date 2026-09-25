# Motor example

Motor is choreography you can interrupt: curves, springs, friction or your own
motions, played across as many properties as you want, and interactive at
every moment. This gallery shows that in seven short chapters, one idea each.
Every chapter shows the code it is running as you interact, and most show
their controller's tracks as live timeline lanes.

| Chapter | Try this | What it shows |
|---|---|---|
| **01 Toggle** | Drag the switch and let go. Tap the heart. | One `TrackController` animates the thumb, its squish and the tint, and the drag's speed carries into the spring. |
| **02 Retarget** | Tap the tabs quickly, then switch to Curve. | A new target starts from the current value, so nothing jumps. Springs keep their speed; curves start their easing again. |
| **03 Card stack** | Throw the top card. | A gesture hands off into a two-phase sequence that starts at the throw's speed. |
| **04 Steps** | Ping the notification. | Each track runs its own steps with a different motion per step, `.at` keyframes that land on time, and a `.sync` barrier. |
| **05 Sync** | Deal the cards, then switch to "On landing". | `.sync(token:)` barriers make tracks wait for each other, and the token decides who waits for whom. |
| **06 Phases** | Drag the player, even during autoplay. | Named phases of `Size` and `Rect` tracks; a drag sets every track, and the release hands back to the phases at your speed. |
| **07 Scrub** | Send, then drag the scrubber. | `pause`, `scrubTo` and `resume` on a choreography of curves, springs and a sync barrier. |

The home screen has a DevTools switch that shows or hides the in-app inspector
from `motor_devtools`.

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
