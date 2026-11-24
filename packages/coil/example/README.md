# Coil catalog

The Coil catalog shows every Coil foundation and component as live examples you can try on a real device. Use it to check behavior best verified interactively: haptics, back gestures, text scaling, and touch versus mouse.

## Run it

Use Flutter 3.47 or later. From this folder:

```sh
flutter run -d macos
flutter run -d chrome
flutter run -d <ios-simulator-id>     # flutter devices lists them
flutter run -d <android-emulator-id>
```

This example keeps platform folders for **iOS, Android, macOS, and web only**, because it is meant for device testing.

## What's in it

- **Home** lists the components, grouped as in `DESIGN.md` §14.
- **Foundations:** colors in both themes, the type scale, spacing and sizes per tier, shapes, and a motion page that plays `quick`, `standard`, `gentle`, and `fade` side by side.
- **One page per component**, with its variants and states as live examples.

The settings button in every page header opens a sheet with preview controls: theme, size tier, text scale, right to left, high contrast, reduced motion, and slow motion. Each control sets the real input a component reads (`MediaQuery`, `Directionality`, `CoilTheme`, `CoilAdaptiveScope`), so a page looks exactly as it would on a device configured that way. Slow motion sets Flutter's `timeDilation` to 5.

The app runs under a bare `WidgetsApp` and is wrapped in `MotorDevTools`, so you can inspect every Coil animation from the floating bubble.

## Mounting it in another app

`package:coil_example/coil_example.dart` exports `coilCatalogRoute()`, an `auto_route` route that carries the whole catalog and its settings. The aggregate gallery in `apps/example` mounts it at `/coil`.
