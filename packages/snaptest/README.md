# Snaptest

[![Code Coverage](./coverage.svg)](./test/)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
[![lints by lintervention][lintervention_badge]][lintervention_link]

**See what your widgets look like during testing.**

![Title banner](./doc/banner.jpg)

Snaptest is simple: call `snap()` in any widget test to save a screenshot of what's currently on screen. Perfect for debugging, documentation, and visual regression testing.

## Installation

```sh
dart pub add dev:snaptest
```

## The Basics

### Just call `snap()` to see your screen

Add one line to any widget test to see what it looks like:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

testWidgets('My widget test', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyPage()));

  // That's it! Screenshot saved to .snaptest/
  await snap();
});
```

The screenshot gets saved as a PNG file in `.snaptest/` using your test name. Great for debugging failing tests or documenting what your widgets actually look like.

### Set up font loading

Snaptest blocks text by default, replacing characters with colored rectangles for cross-platform consistency. However, the **layout** of text still depends on which fonts are loaded. To avoid golden churn when fonts change between environments, load fonts upfront in your `flutter_test_config.dart`:

```dart
// flutter_test_config.dart
import 'dart:async';
import 'package:snaptest/snaptest.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadFonts();
  await testMain();
}
```

This loads Roboto from the Flutter SDK and uses it for Cupertino system fonts, ensuring consistent text layout across macOS, Linux, and Windows. See [Font Rendering](#font-rendering) for customization options.

### Configure your `.gitignore`

```gitignore
**/.snaptest/     # Screenshots (usually not committed)
```

## Settings

By default, `snap()` uses `SnaptestSettings.rendered()` which produces beautiful screenshots with real text, images, shadows, and device frames. Perfect for debugging and documentation.

For simpler, more deterministic screenshots (e.g. for faster tests or when you don't need visual fidelity), use `SnaptestSettings()`:

```dart
await snap(settings: const SnaptestSettings());
```

This blocks text (colored rectangles), disables images, shadows, and device frames.

## Golden File Testing

Snaptest provides three distinct methods for different use cases:

### `snap.golden()` — golden comparison only

Takes a golden comparison screenshot without saving a visual debugging file. The golden is rendered with default `SnaptestSettings()` (blocked text, no shadows) for cross-platform consistency.

```dart
testWidgets('Golden only', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

  await snap.golden(device: Devices.ios.iPhone16Pro);
});
```

### `snap.andGolden()` — visual debugging + golden comparison

Takes both a visual debugging screenshot (saved to `.snaptest/`) and a golden comparison screenshot. Returns the saved file.

```dart
testWidgets('Both snap and golden', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

  await snap.andGolden(
    device: Devices.ios.iPhone16Pro,
    settings: SnaptestSettings.rendered(), // for the visual snap
  );
});
```

The visual snap uses your `settings` (or `SnaptestSettings.global`), while the golden uses `goldenSettings` (or the default `SnaptestSettings()`).

### Updating goldens

When golden tests fail due to intentional changes, update them:
```sh
flutter test --update-goldens
```

## Getting an `Image` directly

Use `snap.image()` to get an `Image` without saving to disk. Same pipeline as `snap()` but returns the image for custom processing:

```dart
testWidgets('Get image', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyPage()));

  final image = await snap.image(
    device: Devices.ios.iPhone16Pro,
    settings: SnaptestSettings.rendered(),
  );

  // Use the image for custom processing...
});
```

## All the Options

### Multiple screenshots per test

When `snap()` is called multiple times in the same test, a counter suffix is automatically added:

```dart
testWidgets('User flow', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyPage()));
  await snap();  // my_test.png

  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await snap();  // my_test_2.png
});
```

You can also provide explicit names:

```dart
await snap(name: 'initial_state');
await snap(name: 'after_tap');
```

### Capture specific widgets
```dart
await snap(from: find.byKey(const Key('my-card')));
```

`from` chooses what gets snapped. snaptest walks up to the nearest
`RepaintBoundary` and captures that boundary.

Use `from` when:
- You want to change the capture source.
- You want to snap a widget or subtree instead of the whole screen.
- You care about the widget's own repaint boundary more than surrounding UI.

If you're thinking "snap this widget," use `from`.

### Crop the result
```dart
final rect = tester.getRect(find.byKey(const Key('my-card')));
await snap(crop: rect);
```

`crop` trims the snapped result to a specific rect in logical pixels. You can
use it on its own or together with `from`.

Use `crop` when:
- You want to keep the current capture source, but trim the final image.
- You want to crop by explicit geometry instead of by widget ancestry.
- You want the image bounded by a widget's rect, but still want screen-level
  visuals like overlays to show up.

The most common pattern is cropping from a finder:
```dart
final cardFinder = find.byKey(const Key('my-card'));
await snap(crop: tester.getRect(cardFinder));
```

That captures the full screen and crops to the widget's bounds, which is useful
when overlays live outside the widget's repaint boundary.

If device framing is enabled, `crop` is applied after the frame is added. That
means the framed image has different dimensions than the raw screen, so a rect
from `tester.getRect(...)` may no longer line up the way it does on an
unframed snap.

You can also combine both features:
```dart
await snap(
  from: find.byKey(const Key('card-boundary')),
  crop: tester.getRect(find.text('Confirm')),
);
```

Use both when:
- You want to snap a specific source selected by `from`.
- But you only want to keep a smaller region inside that snapped result.

If you're thinking "snap from here, but only keep this part," use both.

### Override global settings
```dart
void main() {
  setUpAll(() {
    // Use simplified screenshots for this test file
    SnaptestSettings.global = const SnaptestSettings();
  });

  tearDownAll(SnaptestSettings.resetGlobal);
}
```

### Dedicated screenshot tests with `snapTest`

For tests specifically designed for screenshots, use `snapTest` instead of `testWidgets`. It automatically:
- Adds the `snaptest` tag for easy filtering
- Applies custom settings for the entire test

```dart
import 'package:flutter/material.dart';
import 'package:snaptest/snaptest.dart';

snapTest('Login screen looks correct', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await snap();
});

snapTest(
  'Multi-device homepage',
  devices: {Devices.ios.iPhone16Pro, Devices.android.samsungGalaxyS20},
  (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await snap();
  },
);
```

Run only screenshot tests:
```sh
flutter test --tags snaptest
```

Or exclude them from regular test runs:
```sh
flutter test --exclude-tags snaptest
```

### Test multiple devices and orientations with `TestDevicesVariant`

For running the same test across multiple devices and orientations:

```dart
testWidgets(
  'Responsive layout test',
  variant: TestDevicesVariant(
    {
      Devices.ios.iPhone16Pro,
      Devices.ios.iPad,
      Devices.android.googlePixel9,
      Devices.android.largeTablet,
    },
    orientations: {
      Orientation.portrait,
      Orientation.landscape,
    },
  ),
  (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPage()));
    await snap.golden();
  },
);
```

This runs your test once for each device/orientation combination (8 times in this example). Each test run:
- Sets the test view to the specified device size
- Configures the correct platform (iOS/Android)
- Runs in the specified orientation
- Labels the test with the device and orientation name

### `snap()` parameters

All methods on `snap` accept these common parameters:

```dart
await snap(
  name: 'custom_name',           // Custom filename
  from: find.byKey(key),         // Choose what gets snapped
  crop: tester.getRect(find.byKey(key)), // Trim the snapped result
  settings: SnaptestSettings(),  // Override global settings
  device: Devices.ios.iPhone16,  // Device to simulate
  orientation: Orientation.portrait,
);
```

`from` and `crop` answer different questions:
- `from`: What should be snapped?
- `crop`: Which part of that snapped image should be kept?

As a rule of thumb:
- Start with `from` if you want to change the source.
- Start with `crop` if you want to change the bounds of the final image.
- Use `crop: tester.getRect(finder)` for the common "crop to this widget, but
  still include overlays" case.
- If device framing is enabled, remember that `crop` works on the final framed
  image, not the raw screen dimensions.

`snap.golden()` and `snap.andGolden()` additionally accept:

```dart
await snap.golden(
  prefix: 'goldens/',            // Golden files directory (default)
);

await snap.andGolden(
  settings: SnaptestSettings.rendered(), // For the visual snap
  goldenSettings: SnaptestSettings(),    // For the golden (default)
  prefix: 'goldens/',
);
```

## Settings Reference

### `SnaptestSettings` options:
- **`blockText`**: Replace text with colored rectangles for consistency (default: `true`)
- **`renderImages`**: Render actual images (default: `false`)
- **`renderShadows`**: Render shadows and elevation effects (default: `false`)
- **`includeDeviceFrame`**: Include device frame around content (default: `false`)
- **`pathPrefix`**: Directory where screenshots are saved (default: `'.snaptest/'`)

### Convenience constructors:
- **`SnaptestSettings.rendered()`**: The default — actual text, images, shadows, and device frames
- **`SnaptestSettings()`**: Simplified — blocked text, no images/shadows/frames

## Golden Tools

For advanced use cases, import `golden_tools.dart` to access lower-level utilities:

```dart
import 'package:snaptest/golden_tools.dart';
```

This exports:
- **`captureImage()`** — render an Element to a `ui.Image` with optional blocked text and device frame
- **`BlockedTextPaintingContext`** / **`BlockedTextCanvasAdapter`** — replace text rendering with colored rectangles
- **`loadFont()`** / **`loadFonts()`** — load fonts into the test environment
- **`precacheImages()`** — pre-cache images for accurate rendering
- **`setTestViewForDevice()`** — simulate a device's screen size and safe areas

## Helper Scripts

Clean all screenshots:
```sh
dart run snaptest:clean
```

Clean screenshots from a custom directory:
```sh
dart run snaptest:clean my_custom_dir
```

You can also call `cleanSnaps()` programmatically. Note that it deletes **all** `.snaptest/` directories, so run it once before your full test suite (e.g. in a script), not inside `flutter_test_config.dart` — that runs per test file and would wipe snapshots from earlier files.

Assemble screenshots into a single directory:
```sh
dart run snaptest:assemble
```

### Custom Screenshot Directories

You can customize where screenshots are saved by setting the `pathPrefix` in your settings:

```dart
await snap(
  settings: SnaptestSettings(pathPrefix: 'my_screenshots/'),
);
```

The helper scripts will work with any custom directory name you specify.

## Font Rendering

### Cupertino Fonts

Flutter's iOS/Cupertino typography uses the `CupertinoSystemText` and `CupertinoSystemDisplay` font families. By default, `loadFonts()` overrides these with **Roboto** from the Flutter SDK, ensuring identical text metrics on macOS, Linux, and Windows. This is the recommended setup for golden tests that run on CI.

You can customize this behavior with `CupertinoFontConfig`:

```dart
// Default: Roboto for cross-platform consistency (recommended for goldens)
await loadFonts();

// Use a custom font (must be declared in pubspec.yaml)
await loadFonts(
  cupertinoFonts: CupertinoFontConfig.override(fontFamily: 'Inter'),
);

// Use SF Pro on macOS for visual debugging (not recommended for goldens)
// Throws if not on macOS or SF Pro is not installed.
await loadFonts(
  cupertinoFonts: CupertinoFontConfig.fromMacOsSystemFonts(),
);

// Use SF Pro on macOS, fall back to Roboto elsewhere
// WARNING: can lead to inconsistencies in goldens between platforms
await loadFonts(
  cupertinoFonts: CupertinoFontConfig.fromMacOsSystemFonts(
    fallbackOverride: 'Roboto',
  ),
);
```

### macOS: SF Pro Fonts

For the most accurate iOS rendering on macOS, install Apple's SF Pro fonts:

1. Download SF Pro fonts from [Apple's developer site](https://developer.apple.com/fonts/)
2. Install the fonts to `/Library/Fonts` (system-wide installation)
3. Use `CupertinoFontConfig.fromMacOsSystemFonts()` in your `loadFonts()` call

Note that SF Pro is licensed by Apple for creating mock-ups of iOS, iPadOS, macOS, and tvOS interfaces only. It cannot be redistributed or used on non-Apple platforms.

### Font Limitations

Due to Flutter's test environment limitations:
- **Google Fonts** only work if bundled as local assets (not fetched remotely)
- **Custom fonts** must be included in your `pubspec.yaml`

This ensures consistent screenshots across environments, but may differ slightly from your actual app.

---

[dart_install_link]: https://dart.dev/get-dart
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[mason_link]: https://github.com/felangel/mason
[very_good_ventures_link]: https://verygood.ventures
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40
