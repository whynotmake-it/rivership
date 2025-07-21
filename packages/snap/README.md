# Snap

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)


Snap photos in your widget tests.

## Installation 💻

**❗ In order to start using Snap you must have the [Dart SDK][dart_install_link] installed on your machine.**

Install `snap` as a dev dependency:

```sh
dart pub add dev:snap
```

---

## Quick Start Guide 🚀

There are two main ways of using Snap:


### 1. Call `snap()` from any widget test

You can take snapshots in any widget test by using the `snap` function.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snap/snap.dart';

void main() {
  testGroup('My Page', () {
    widgetTest('Loaded State', (tester, snap) async {
      await tester.pumpWidget(MyPage());

      expect(find.byType(MyPage), findsOneWidget);
      
      // Do this anywhere
      await snap();
    });
  });
}

```

The screenshot will be saved in a `.snap` directory next to the current test file, using the name of the test.

If you want to take multiple screenshots, you can pass a name to the `snap` function.

```dart
await snap('loaded');
await snap('tapped button');
```

By default, snapshots will be rendered using the "Ahem" font and without all images in the default Flutter widget test view.

You can pass a list of fake devices (`FakeDevice`) to the `snap` function to render the screenshot as if it was taken on real devices.

You can also override the global settings by accessing the `SnapSettings` class.

If you want your screenshots to be rendered as close to the real device as possible, you need to call `enableRealRenderingForTest()` at the start of your test.

For more information, check out the documentation for the `snap` function.

Alternatively, use the `screenshotTest` function, which will automatically enable real rendering for the test:


### 2. Writing `screenshotTest`s
  
In your test setup, in addition to your `testWidget` widget tests, you can add `screenshotTest` tests.
These allow you to easily take snapshots of your widgets, which will be rendered like they would be in
a real device.

You can pass a list of devices, all of which will take screenshots seperately.

`screenshotTest`s are automatically tagged using the 'screenshot' tag, so you can selectively run and exclude them
using `flutter test -t screenshot` and `flutter test -x -screenshot` respectively.


```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snap/snap.dart';

void main() {
  testGroup('My Page', () {
    screenshotTest('Loaded State', devices: [FakeDevice.iphone16Pro], (tester) async {
      await tester.pumpWidget(MyPage());
      await snap('loaded');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await snap('tapped button');
    });
  });
}

```

## Helper Scripts

`snap` comes with with two scripts that you can run from the root of your project.

### clean

```sh
dart run snap:clean
```

This script will delete all the screenshots in the `.snap` directories around your project.

### assemble

```sh
dart run snap:assemble
```

Will take all the screenshots in the `.snap` directories around your project and assemble them into a single directory at the root of your project (and potentially do something cool with them in the future 👀)

---


[dart_install_link]: https://dart.dev/get-dart
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[mason_link]: https://github.com/felangel/mason
[very_good_ventures_link]: https://verygood.ventures
