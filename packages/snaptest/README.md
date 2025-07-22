# Snaptest

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)


Snap photos in your widget tests.

## Installation 💻

**❗ In order to start using Snaptest you must have the [Dart SDK][dart_install_link] installed on your machine.**

Install `snaptest` as a dev dependency:

```sh
dart pub add dev:snaptest
```

---

## Quick Start Guide 🚀

There are two main ways of using Snaptest:

### 0. Add `.snaptest` to your `.gitignore`

Unless you want snapshots checked into version control, add this pattern to your `.gitignore` file:

```gitignore
**/.snaptest/
```

This will ignore all `.snaptest` directories throughout your project.


### 1. Use `snapTest()` for screenshot tests

Use the `snapTest` function instead of `testWidgets` for tests that take screenshots. This automatically adds the `screenshot` tag for easy filtering.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  group('My Page', () {
    snapTest('Loaded State', (tester) async {
      await tester.pumpWidget(MyPage());

      expect(find.byType(MyPage), findsOneWidget);
      
      // Take a screenshot
      await snap();
    });
  });
}
```

The screenshot will be saved in a `.snaptest` directory next to the current test file, using the name of the test.

### 2. Multiple screenshots and device testing

You can take multiple screenshots and test on different devices:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  group('My Page', () {
    snapTest(
      'Loaded State', 
      (tester) async {
        await tester.pumpWidget(MyPage());
        await snap('loaded');

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await snap('tapped button');
      },
      settings: SnaptestSettings(
        devices: [
          Devices.ios.iPhone16Pro,
          Devices.android.samsungGalaxyS20,
        ],
      ),
    );
  });
}
```

### 3. Advanced configuration

You can configure rendering options using `SnaptestSettings`:

```dart
snapTest(
  'Full rendering test',
  (tester) async {
    await tester.pumpWidget(MyApp());
    await snap();
  },
  settings: SnaptestSettings.full([
    Devices.ios.iPhone16Pro,
    Devices.android.samsungGalaxyS20,
  ]),
);
```

Available settings:
- `blockText`: Whether to block text rendering (default: `true`)
- `renderImages`: Whether to render images (default: `false`)
- `renderShadows`: Whether to render shadows (default: `false`)
- `devices`: List of devices to test on (default: `[WidgetTesterDevice()]`)

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
