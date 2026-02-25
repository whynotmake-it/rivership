## 0.2.3+1

 - **FIX**: `snap` with `from:` did not work in goldens.

## 0.2.3

 - **FEAT**: add `TestOnDevice` variant, so you can quickly simulate multiple devices in widget tests.

## 0.2.2+1

 - **DOCS**: remove outdated font loading section from README.

## 0.2.2

 - **FEAT**: improve font loading drastically.

    - Remove dependency on spot package
    - Load actual SFPro fonts on macOS if you have them installed, otherwise
      print a warning and fall back to Roboto.
    - Allow calling `snap()` from within `runAsync`, even with font loading.


## 0.2.1

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.2.1-dev.0

 - **FEAT**: add sequence animations to motor.
 - **FEAT**: add TrimmedMotion as a way to take subsets of any motion.

## 0.2.0

> Note: This release has breaking changes.

 - **REFACTOR**: rename `SnaptestSettings.full` to `SnaptestSettings.rendered`.
 - **FEAT**: add `loadFontsAndIcons()` and recommend adding it to `flutter_test_config.dart`.
 - **FEAT**: support passing orientations to settings.
 - **DOCS**: added banner as screenshot to pubspec.
 - **DOCS**: updated banner with new settings.
 - **DOCS**: document `snapTest` function in README.
 - **DOCS**: documented flutter_test_config usage.
 - **DOCS**: document new orientations.
 - **BREAKING** **REFACTOR**: move pathPrefix to settings.
 - **BREAKING** **REFACTOR**: renamed the default test tag to `snaptest`.
 - **BREAKING** **REFACTOR**: removed `appendDeviceName` in favor of `alwaysAppendDeviceName` and `alwaysAppendOrientation`.

## 0.1.0

 - **FEAT**: skip drawing paragraphs in golden canvas for cleaner images (#144).
 - **FEAT**: support golden comparison (#142).

## 0.1.0-dev.3

 - **DOCS**: update banner image (#140).

## 0.1.0-dev.2

 - **FEAT**: allow include device frame (#137).

## 0.1.0-dev.1

## 0.1.0

- feat: initial commit 🎉
