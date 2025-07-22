# Snaptest

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)


Snap photos in your widget tests.

![Title banner](./doc/banner.jpg)

## Installation 💻

**❗ In order to start using Snaptest you must have the [Dart SDK][dart_install_link] installed on your machine.**

Install `snaptest` as a dev dependency:

```sh
dart pub add dev:snaptest
```

---

## ⚠️ Font Limitations

**Important:** Due to limitations in Flutter's golden test environment, this package has the following font-related constraints:

- **Cupertino System Fonts**: iOS system fonts (CupertinoSystemText/CupertinoSystemDisplay) are not available in the test environment and are automatically overridden with Roboto fonts for consistent rendering across platforms.

- **Google Fonts**: The `google_fonts` package will only work in golden tests if fonts are bundled as local assets in your `pubspec.yaml`. Remote font fetching (the default behavior) will not work in the test environment.

- **Custom Fonts**: If you use custom fonts in your app, ensure they are included as local assets in your `pubspec.yaml` and properly loaded during tests for accurate screenshots.

These limitations ensure consistent, reproducible screenshots across different test environments, but may result in visual differences from your actual app when using iOS system fonts or remote fonts.

---

## Quick Start Guide 🚀

### 0. Add `.snaptest` to your `.gitignore`

Unless you want snapshots checked into version control, add this pattern to your `.gitignore` file:

```gitignore
**/.snaptest/
```

This will ignore all `.snaptest` directories throughout your project.

### 1. Call `snap()` in existing tests

The simplest way to get started is to add `snap()` calls to your existing widget tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  group('My Page', () {
    testWidgets('Loaded State', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MyPage(),
        ),
      );

      expect(find.byType(MyPage), findsOneWidget);
      
      // Just add this line to take a screenshot
      await snap();
    });
  });
}
```

The screenshot will be saved in a `.snaptest` directory next to the current test file, using the name of the test.

### 2. Use `snapTest()` for dedicated screenshot tests

For tests specifically designed for screenshots, use `snapTest` instead of `testWidgets`. This automatically adds the `screenshot` tag for easy filtering:

```dart
snapTest('Loaded State', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: MyPage(),
    ),
  );

  expect(find.byType(MyPage), findsOneWidget);
  
  // Take a screenshot - saved as "Loaded State.png"
  await snap();
});
```

### 3. Multiple screenshots with custom names

You can take multiple screenshots in a single test by providing custom names:

```dart
snapTest('User interaction flow', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyPage()));
  
  // Take initial screenshot
  await snap('initial_state');

  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  // Take screenshot after interaction
  await snap('after_button_tap');
});
```

### 4. Device-specific testing

Test your UI on different devices by configuring the settings:

```dart
snapTest(
  'Multi-device test',
  (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPage()));
    await snap();
  },
  settings: SnaptestSettings(
    devices: [
      Devices.ios.iPhone16Pro,
      Devices.android.samsungGalaxyS20,
      const WidgetTesterDevice(), // Default test environment
    ],
  ),
);
```

This will generate separate screenshots for each device, with device names appended to the filename.

### 5. Capturing specific widgets

You can capture screenshots of specific widgets using the `from` parameter:

```dart
snapTest('Card widget only', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Card(
            key: const Key('my-card'),
            child: const Text('Hello World'),
          ),
        ),
      ),
    ),
  );

  // Only capture the card widget
  await snap(
    name: 'card_only',
    from: find.byKey(const Key('my-card')),
  );
});
```

### 6. Advanced rendering options

Configure how screenshots are rendered using `SnaptestSettings`:

```dart
snapTest(
  'Full rendering test',
  (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyApp()));
    await snap();
  },
  settings: SnaptestSettings.full([
    Devices.ios.iPhone16Pro,
    Devices.android.samsungGalaxyS20,
  ]),
);
```

#### Available `SnaptestSettings` options:

- **`devices`**: List of devices to test on (default: `[WidgetTesterDevice()]`)
- **`blockText`**: Whether to block text rendering for consistent screenshots (default: `true`)
- **`renderImages`**: Whether to render actual images (default: `false`)
- **`renderShadows`**: Whether to render shadows (default: `false`)

#### Convenience constructors:

- **`SnaptestSettings()`**: Default settings with blocked text and no images/shadows
- **`SnaptestSettings.full(devices)`**: Full rendering with images, shadows, and real text

### 7. Global settings

You can set global defaults for all tests:

```dart
void main() {
  setUpAll(() {
    SnaptestSettings.global = SnaptestSettings(
      devices: [Devices.ios.iPhone16Pro],
      renderShadows: true,
    );
  });

  tearDownAll(() {
    SnaptestSettings.resetGlobal();
  });

  // Your tests here...
}
```

### 8. Additional `snap()` parameters

The `snap()` function supports several parameters for customization:

```dart
await snap(
  name: 'custom_name',           // Custom filename
  from: find.byKey(key),         // Specific widget to capture
  settings: SnaptestSettings(),  // Override global settings
  pathPrefix: 'screenshots/',    // Custom directory (default: '.snaptest/')
  appendDeviceName: false,       // Don't append device name to filename
);
```

## Helper Scripts

`snaptest` comes with with two scripts that you can run from the root of your project.

### clean

```sh
dart run snaptest:clean
```

This script will delete all the screenshots in the `.snaptest` directories around your project.

### assemble

```sh
dart run snaptest:assemble
```

Will take all the screenshots in the `.snaptest` directories around your project and assemble them into a `.snaptest/assets` directory at the root of your project (and potentially do something cool with them in the future 👀)

---


[dart_install_link]: https://dart.dev/get-dart
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[mason_link]: https://github.com/felangel/mason
[very_good_ventures_link]: https://verygood.ventures
