# Snapper

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)


Snap photos in your widget tests.

## Installation 💻

**❗ In order to start using Snapper you must have the [Dart SDK][dart_install_link] installed on your machine.**

Install `snapper` as a dev dependency:

```sh
dart pub add dev:snapper
```

---

## Quick Start Guide 🚀

There are two main ways of using Snapper:

### 0. Add `.snapper` to your `.gitignore`

Unless you want snapshots checked into version control, add this pattern to your `.gitignore` file:

```gitignore
**/.snapper/
```

This will ignore all `.snapper` directories throughout your project.


### 1. Call `snap()` from any widget test

You can take snapshots in any widget test by using the `snap` function.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snapper/snapper.dart';

void main() {
  testGroup('My Page', () {
    testWidgets('Loaded State', (tester) async {
      await tester.pumpWidget(MyPage());

      expect(find.byType(MyPage), findsOneWidget);
      
      // Do this anywhere
      await snap();
    });
  });
}

```

The screenshot will be saved in a `.snapper` directory next to the current test file, using the name of the test.

If you want to take multiple screenshots, you can pass a name to the `snap` function.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:snapper/snapper.dart';

void main() {
  testGroup('My Page', () {
    screenshotTest('Loaded State', devices: [Devices.ios.iPhone16Pro], (tester) async {
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

`snapper` comes with with two scripts that you can run from the root of your project.

### clean

```sh
dart run snapper:clean
```

This script will delete all the screenshots in the `.snapper` directories around your project.

### assemble

```sh
dart run snapper:assemble
```

Will take all the screenshots in the `.snapper` directories around your project and assemble them into a `.snapper/assets` directory at the root of your project (and potentially do something cool with them in the future 👀)

---


[dart_install_link]: https://dart.dev/get-dart
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[mason_link]: https://github.com/felangel/mason
[very_good_ventures_link]: https://verygood.ventures
