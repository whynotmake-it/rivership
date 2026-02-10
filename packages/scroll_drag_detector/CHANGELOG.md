## 0.1.0+2

 - **FIX**: immediately start clearing overscroll when letting go.

## 0.1.0+1

 - **FIX**: dragging up from a snap point performes one frame of scroll before transitioning to dragging.

## 0.1.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: callbacks now indicate if a scroll did, would have, or will occur.

    All callbacks in `ScrollDragDetector` besides down and cancel now pass an extra bool that
    
    - For drag update, whether the drag would have been a scroll gesture
    - For drag end, whether the drag will turn into a scroll gesture
    
    This allows consumers to better handle interactions between dragging and scrolling.


## 0.0.4

 - **FIX**: velocity scaling when overdragging with resistance.
 - **FIX**: secondary animation in cupertino sheet.
 - **FEAT**: sheets support snapping points now.

## 0.0.3

 - **FEAT**: add `onlyDragWhenScrollWasAtTop` parameter.

## 0.0.2+1

 - **FIX**: don't render overscroll indicators while we drag.
 - **FIX**: only pay attention to drags on the axis we care about.
 - **FIX**: only pay attention to relevant axes.

## 0.0.2

 - **FEAT**: stupid simple sheet and drag detector (#154).

