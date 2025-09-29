## 0.4.1

 - **FIX**: velocity scaling when overdragging with resistance.
 - **FIX**: secondary animation in cupertino sheet.
 - **FEAT**: cupertino sheet can now be dragged over its limits with resistance.
 - **FEAT**: sheets support snapping points now.
 - **FEAT**: cupertino sheet top padding is based on safe area now.

## 0.4.0+2

 - Update a dependency to the latest release.

## 0.4.0+1

 - Update a dependency to the latest release.

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: add `onlyDragWhenScrollWasAtTop` and default to true.

    This allows sheets to prevent closing accidentally when the user just wanted to scroll to the top, especially in short lists. It matches iOS default behavior.


## 0.3.1

 - **FEAT**: add `clearBarrierImmediately` setting that allows the route to make underlying routes interactible straight away (#183).

## 0.3.0+1

 - **FIX**: routes below `StupidSimpleCupertinoSheetRoute` took too long to become interactable (#180).

## 0.3.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.3.0-dev.3

 - **FIX**: import internal from package:meta again.

## 0.3.0-dev.2

 - **FEAT**: add clip behavior option to sheet (#173).

## 0.3.0-dev.1

 - **FIX**: don't render overscroll indicators while we drag.
 - **FIX**: only pay attention to drags on the axis we care about.
 - **FIX**: only pay attention to relevant axes.

## 0.3.0-dev.0

 - **BUILD**: fixed package versioning

## 0.0.2-dev.2

 - **FIX**: default to `snapToEnd` in sheet motions for compatibility with the latest motor update.

## 0.0.2-dev.1

 - Update a dependency to the latest release.

## 0.0.2-dev.0+1

 - **FIX**: sheets don't incorrectly use an old drag end velocity anymore.

## 0.0.2

 - **FIX**: remove hard-coded padding from sheet (#155).
 - **FEAT**: stupid simple sheet and drag detector (#154).

