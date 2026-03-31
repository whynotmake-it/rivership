## 1.0.0-dev.2

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: remove `renderImages` from snaptest settings, always precache and render them.
 - **BREAKING** **REFACTOR**: move `captureImage` into extensions on `Finder` and `Element`.

## 1.0.0-dev.1

> Note: This release has breaking changes.

 - **FIX**: make sure `loadFonts` can be called before test execution.
 - **FIX**: don't force reset platform override to null after test.
 - **FIX**: always tear down global settings correctly.
 - **FEAT**: `snap.andGolden` now returns both files separately in a record.
 - **FEAT**: export cleanSnaps function for programmatic snapshot cleanup.

    Add cleanSnaps() as a public API to allow users to clean screenshots
    programmatically from their tests.

 - **FEAT**: add automatic counter to prevent overwriting snapshots.

    When snap() is called multiple times without a name, filenames now include
    a counter suffix (_2, _3, etc.) to prevent overwriting.

 - **DOCS**: document font loading.
 - **BREAKING** **REFACTOR**: remove devices and orientations from SnaptestSettings.

    Move device iteration responsibility to TestDevicesVariant and add
    explicit device/orientation parameters to snap(). This eliminates the
    duplicate concept of device configuration in both settings and variant.
    
    
    orientations. Use TestDevicesVariant for multi-device testing or pass
    device/orientation directly to snap(). snap() now returns Future<File>
    instead of Future<List<File>>.

 - **BREAKING** **REFACTOR**: replace WidgetTesterDevice with null to leave view unchanged.

    - The devices parameter is now a Set<DeviceInfo?> instead of List<DeviceInfo>
    - Remove any imports of WidgetTesterDevice
    
    Unlike the previous WidgetTesterDevice which represented a default test environment, null now simply leaves the view in whatever state it's currently in without any modifications. This allows for more flexible testing scenarios where users have pre-configured their view.

 - **BREAKING** **REFACTOR**: rename TestOnDevices to TestDevicesVariant and extend ValueVariant.
 - **BREAKING** **FEAT**: make Cupertino font loading on macOS opt-in.
 - **BREAKING** **FEAT**: default `SnaptestSettings.global` to be fully rendered and add `SnaptestSettings.goldens`.
 - **BREAKING** **FEAT**: simplify syntax from `snap(matchToGolden: true)` to `snap.golden()` and `snap.andGolden()`.
 - **BREAKING** **FEAT**: render blocked text with tighter boxes and paragraphs.

## 0.3.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: disable anti-aliasing on blocked text painting for better consistency.

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
