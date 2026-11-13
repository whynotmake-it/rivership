# coil catalog

The coil catalog shows every coil foundation and component as live examples you can try on a real device. Use it to check behavior that tests can't feel: haptics, back gestures, text scaling and touch versus mouse.

## Run it

Use Flutter 3.47 or later. From this folder:

```sh
flutter run -d macos
flutter run -d chrome
flutter run -d <ios-simulator-id>     # flutter devices lists them
flutter run -d <android-emulator-id>
```

This example keeps platform folders for **iOS, Android, macOS and web only**, because it is meant for device testing. The repo's other per-package examples ship none.

## What's in it

- **Home** lists every component in DESIGN.md §14, grouped the same way. Components that aren't built yet are listed as planned.
- **Foundations:** colors in both themes, the type scale, spacing and sizes per tier, shapes, and a motion page that plays `quick`, `standard`, `gentle` and `fade` side by side.
- **One page per component**, with its variants and states as live examples.

The settings button in every page header opens a sheet with preview controls: theme, size tier, text scale, right to left, high contrast, reduced motion and slow motion. Each control sets the real input a component reads (`MediaQuery`, `Directionality`, `CoilTheme`, `CoilAdaptiveScope`), so a page looks exactly as it would on a device set up that way. Slow motion sets Flutter's `timeDilation` to 5.

The app runs under a bare `WidgetsApp` and is wrapped in `MotorDevTools`, so you can inspect every coil animation from the floating bubble.

## Add a page

A new page is one file plus one registry line.

1. Write `lib/src/pages/components/<name>_page.dart` with the page widget and its entry:

   ```dart
   const badgeEntry = CatalogEntry(
     slug: 'badge',
     title: 'Badge', // the name DESIGN.md §14 uses
     group: CatalogGroup.leafControls,
     summary: 'Status and categories.',
     page: BadgePage.new,
   );
   ```

   Build the page from `CatalogPage` and `DemoSection` in `lib/src/widgets/catalog_page.dart`.

2. Add `badgeEntry` to `catalogEntries` in `lib/src/registry.dart`.

The home screen matches entries to DESIGN.md's list by `title`, so the planned row turns into a link. The route and the smoke tests pick up the page automatically.

## Tests

`flutter test` opens every page in light and dark, at the pointer and touch tiers, and fails on any overflow or exception. It also checks navigation and that the settings apply live. Component goldens live in coil's own tests, not here.

## Mounting it in another app

`package:coil_example/coil_example.dart` exports `coilCatalogRoute()`, an `auto_route` route that carries the whole catalog and its settings. The aggregate gallery in `apps/example` mounts it at `/coil`.
