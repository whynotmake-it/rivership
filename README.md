# Rivership Workspace

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
[![Code Coverage](./coverage-total.svg)](./coverage-total.svg)
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

Rivership is a set of opinionated tools that will get you shipping your Flutter app in no time!

This monorepo contains Rivership, and all its associated packages. Check out the `packages/` directory to explore them, or jump straight to the [Rivership README](./packages/rivership/README.md).

Try the examples of Heroine, Motor, Coil, and Stupid Simple Sheet in your browser at [whynotmake-it.github.io/rivership](https://whynotmake-it.github.io/rivership/).

## Package overview

| Package | pub.dev | Description | Example |
| --- | --- | --- | --- |
| [rivership](./packages/rivership) | [![Pub Version](https://img.shields.io/pub/v/rivership)](https://pub.dev/packages/rivership) | An opinionated infrastructure package for use with hooks_riverpod. |  |
| [rivership_test](./packages/rivership_test) | [![Pub Version](https://img.shields.io/pub/v/rivership_test)](https://pub.dev/packages/rivership_test) | Testing utilities to accompany the rivership package. |  |
| [motor](./packages/motor) | [![Pub Version](https://img.shields.io/pub/v/motor)](https://pub.dev/packages/motor) | A complete motion orchestration system for Flutter — multi-property tracks, keyframes, loops, sync barriers, phases, springs, and curves under one API. | [Open Example](https://whynotmake-it.github.io/rivership/#/motor) |
| [motor_widgets](./packages/motor_widgets) | Not published yet | Spring-driven versions of Flutter's implicit animation widgets, layout transitions, and drag-and-drop, built on Motor. |  |
| [motor_devtools](./packages/motor_devtools) | Not published yet | Optional in-app timeline inspector and motion tuner for Motor. |  |
| [heroine](./packages/heroine) | [![Pub Version](https://img.shields.io/pub/v/heroine)](https://pub.dev/packages/heroine) | The queen of hero transitions. Flutter's most addictive interactions. | [Open Example](https://whynotmake-it.github.io/rivership/#/heroine) |
| [stupid_simple_sheet](./packages/stupid_simple_sheet) | [![Pub Version](https://img.shields.io/pub/v/stupid_simple_sheet)](https://pub.dev/packages/stupid_simple_sheet) | Draggable, spring-animated modal sheet routes for Flutter with scroll handoff and snapping. | [Open Example](https://whynotmake-it.github.io/rivership/#/stupid_simple_sheet) |
| [scroll_drag_detector](./packages/scroll_drag_detector) | [![Pub Version](https://img.shields.io/pub/v/scroll_drag_detector)](https://pub.dev/packages/scroll_drag_detector) | A drag gesture detector that coordinates with nested scroll views. |  |
| [snaptest](./packages/snaptest) | [![Pub Version](https://img.shields.io/pub/v/snaptest)](https://pub.dev/packages/snaptest) | Snap photos and record videos in your Flutter widget tests. |  |
| [fixed_ticker](./packages/fixed_ticker) | [![Pub Version](https://img.shields.io/pub/v/fixed_ticker)](https://pub.dev/packages/fixed_ticker) | A drop-in Ticker replacement that uses Timer.periodic to gate frame callbacks at a fixed interval. |  |
| [coil](./packages/coil) | Not published yet | A Flutter design system built on Motor motion. Works under any WidgetsApp. | [Open Example](https://whynotmake-it.github.io/rivership/#/coil) |
| [coil_cli](./packages/coil_cli) | Not published yet | Ejects Coil components into a Flutter app, merges upstream changes into local copies, and tests their interaction patterns. |  |


---
