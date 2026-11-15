# Rivership Workspace

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
[![Code Coverage](./coverage-total.svg)](./coverage-total.svg)
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

Rivership is a set of opinionated tools that will get you shipping your Flutter app in no time!

This monorepo contains Rivership, and all its associated packages. Check out the `packages/` directory to explore them, or jump straight to the [Rivership README](./packages/rivership/README.md).

Try the examples of Heroine, Motor, coil, Merging Dots and Stupid Simple Sheet in your browser at [whynotmake-it.github.io/rivership](https://whynotmake-it.github.io/rivership/).

## Package overview

| Package | pub.dev | Description | Example |
| --- | --- | --- | --- |
| [rivership](./packages/rivership) | [![Pub Version](https://img.shields.io/pub/v/rivership)](https://pub.dev/packages/rivership) | An opinionated infrastructure package for use with hooks_riverpod. |  |
| [rivership_test](./packages/rivership_test) | [![Pub Version](https://img.shields.io/pub/v/rivership_test)](https://pub.dev/packages/rivership_test) | A package containing testing utilities to accompany the rivership package. |  |
| [motor](./packages/motor) | [![Pub Version](https://img.shields.io/pub/v/motor)](https://pub.dev/packages/motor) | A unified motion system for Flutter - physics-based springs and duration-based curves under one API. | [Open Example](https://whynotmake-it.github.io/rivership/#/motor) |
| [motor_widgets](./packages/motor_widgets) | Not published yet | Spring-driven versions of Flutter's implicit animation widgets, built on Motor. Retargeting keeps velocity instead of restarting. |  |
| [motor_devtools](./packages/motor_devtools) | Not published yet | Lightweight in-app inspection and motion tuning tools for Motor. |  |
| [heroine](./packages/heroine) | [![Pub Version](https://img.shields.io/pub/v/heroine)](https://pub.dev/packages/heroine) | The queen of hero transitions. Flutter's most addictive interactions. | [Open Example](https://whynotmake-it.github.io/rivership/#/heroine) |
| [merging_dots](./packages/merging_dots) | Not published yet | Dots that merge into each other, for loading indicators, dot-matrix icons and characters. Rendered by fragment shaders, animated with Motor. | [Open Example](https://whynotmake-it.github.io/rivership/#/merging_dots) |
| [stupid_simple_sheet](./packages/stupid_simple_sheet) | [![Pub Version](https://img.shields.io/pub/v/stupid_simple_sheet)](https://pub.dev/packages/stupid_simple_sheet) | A simple sheet widget for Flutter. | [Open Example](https://whynotmake-it.github.io/rivership/#/stupid_simple_sheet) |
| [scroll_drag_detector](./packages/scroll_drag_detector) | [![Pub Version](https://img.shields.io/pub/v/scroll_drag_detector)](https://pub.dev/packages/scroll_drag_detector) | A drag gesture detector that can deal with scroll views inside of it. |  |
| [snaptest](./packages/snaptest) | [![Pub Version](https://img.shields.io/pub/v/snaptest)](https://pub.dev/packages/snaptest) | Snap photos in your widget tests. |  |
| [fixed_ticker](./packages/fixed_ticker) | [![Pub Version](https://img.shields.io/pub/v/fixed_ticker)](https://pub.dev/packages/fixed_ticker) | A drop-in Ticker replacement that uses Timer.periodic to gate frame callbacks at a fixed interval. |  |
| [coil](./packages/coil) | Not published yet | A Flutter design system built on Motor springs, inspired by Fluid Functionalism. Works under any WidgetsApp. | [Open Example](https://whynotmake-it.github.io/rivership/#/coil) |
| [coil_cli](./packages/coil_cli) | Not published yet | Ejects coil components into a Flutter app, merges coil's later changes into the copies, and checks their interaction patterns in tests. |  |


---
