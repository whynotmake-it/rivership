## 0.1.0-dev.1

> Note: This release has breaking changes.

 - **FEAT**(motor_devtools): add in-app inspection and motion tuning tools for motor (#324).

    MotorDevTools wraps an app with a draggable bubble that opens a panel of
    live motor controllers. Each controller has play, pause, replay and speed
    controls, a live timeline that scrubs on drag, and a motion editor whose
    session-only edits can be copied as code. MotorTimeline is a read-only
    timeline widget, and the const kMotorDevTools flag removes the tools from a
    build.

 - **BREAKING** **FEAT**(motor_widgets): drag and drop with MotionLayoutGroup, MotionReorderable, MotionDraggable and MotionDragToScroll (#351).

    * refactor(motor)!: move MotionDraggable to motor_widgets and animate every drop
    
    MotionDraggable now lives in motor_widgets, next to the other spring-driven
    versions of Flutter widgets, and package:motor no longer exports it.
    
    It still runs Flutter's Draggable underneath, so plain DragTargets get the
    same data and callbacks. Instead of only animating the return, it paints its
    own feedback in one overlay flight from pickup to landing:
    
    - an accepted drop flies to where the item now lives, found like a Hero by
      its tag (data by default) once the drop has been laid out;
    - a rejected or canceled drop springs back to the source;
    - a drop with nowhere to land plays an exit where it was dropped, by
      default shrinking and fading out.
    
    The landing starts with the release velocity and follows a destination that
    moves. The destination hides its child while the feedback lands, and
    grabbing the feedback mid-landing drags it on from where it is. The flight
    owns its controller, so it outlives a source that is disposed mid-drag, a
    popped route or an unmounted overlay.
    
    transitions animates the feedback's MotionDraggableTrack scale, rotation and
    opacity per phase (dragging, accepted, rejected) and when the destination is
    found or lost; feedbackBuilder gets the live, smoothed velocity. The feedback
    is always laid out at the child's measured size. MotionLongPressDraggable
    replaces LongPressDraggable.
    
    onlyReturnWhenCanceled and feedbackMatchesConstraints are removed, and
    motion defaults to CupertinoMotion.smooth(). motor's README, CHANGELOG and
    MIGRATION, and the motor_devtools README, describe the move.
    
    
    
    * feat(motor_widgets): drag and drop with MotionLayoutGroup, MotionReorderable and MotionDragToScroll
    
    MotionLayoutGroup and MotionLayoutItem fly items to their new places when
    a rebuild moves them. Items are matched by id, so lazy lists need no keys,
    and an item flies into another container of the same group. An item
    checks whether it moved only when it is rebuilt: scrolling never makes it
    fly, and nothing runs in frames without a rebuild.
    
    MotionReorderable takes drags over a list, grid, wrap or sliver and tells
    its builder where they would drop, between two items. The builder places a
    MotionDropGap or draws a line. onMove covers reorders, drops from other
    reorderables and screen-reader moves, and may return a Future that keeps
    the drop pending. The drop stays when the drag leaves, and letting go
    outside drops there, unless keepsDropOnLeave is false.
    
    MotionDraggable lands on the MotionLayoutItem with its id, unique per
    group, and hands the rest of the landing to the item's spring. start picks
    an immediate or long-press start, handleOnly starts it from a
    MotionDragHandle, feedback and childWhenDragging get the measured size, and
    MotionDragDetails.morph lets the feedback turn into its destination.
    
    MotionDragToScroll scrolls the nearest scroll view below it while a drag
    is near one of its edges, on a spring.
    
    
    
    * fix(motor_widgets): don't create tickers while disposing
    
    MotionReorderable and MotionDragToScroll held their ticker in a late
    final field, so a state that never ticked created it in dispose, which
    looks up TickerMode through a deactivated element and asserts. Create
    the ticker on first use and only dispose or stop one that exists. Fixes
    15 failing MotionReorderable tests.
    
    
    
    
    * fix(motor_widgets): reorder column-major wraps and horizontal grids
    
    MotionReorderable assumed items on several rows and columns run along
    rows, and only split horizontal flows into lines, so in a
    Wrap(direction: Axis.vertical) or a GridView scrolling horizontally the
    drop index came out row-major and scrambled. Tell the way items wrap
    from how consecutive items follow each other, falling back to across
    the scroll axis, split lines along either axis, and order the lines by
    the cross direction, so RTL and reversed scrollables work too.
    
    
    
    
    * perf(motor_widgets): rebuild MotionReorderable items only when what they read changes
    
    The reorderable's scope notified its items on every rebuild, so items
    the builder kept were rebuilt on each hover move. Notify only when the
    motion or sliver mode the items read changes. Look item indices up in
    a map built once per widget instead of a linear search per slot.
    
    
    
    
    * fix(motor_widgets): measure painted rects through ancestor transforms
    
    paintedGlobalRect added each ancestor's paint offset, which is in that
    ancestor's coordinates, straight onto a global rect, and slots were
    measured as localToGlobal plus their unscaled size. Under a
    Transform.scale or an InteractiveViewer, MotionReorderable placed the
    drop by the wrong centers and MotionDragToScroll and visible rects were
    off by the scale. Compose the paint offsets into the paint transform
    instead, and measure laid out rects through it.
    
    Landing sites keep their rect as the painted top left with the size in
    their own coordinates, which is what the landing flight, following the
    site's leader layer, expects.
    
    
    
    
    * fix(motor_widgets): only land a drop in a landing scope that is showing
    
    A drop accepted by a plain DragTarget lands in the innermost
    MotionLayoutGroup whose box contains the pointer. A group in a page
    covered by an opaque route, or in an Offstage subtree, keeps the size
    of its last layout, so a deeper one there took the drop and the
    feedback flew off toward a site that can't be seen. Skip scopes whose
    tickers are off or that are offstage.
    
    
    
    
    * docs(motor_widgets): note that MotionDragToScroll needs a Draggable's data
    
    Flutter's DragTarget reports neither the entry nor the moves of a
    Draggable whose data is null, so MotionDragToScroll can't see one.
    
    
    
    
    * fix(motor_widgets): tick a MotionLayoutItem's handed-over visuals at its group's rate
    
    The item's own controller, which carries a landing's scale, rotation and
    opacity on after a hand-off, ignored MotionLayoutGroup.tickerRate,
    which the group's flights follow.
    
    
    
    
    ---------


## 0.1.0-dev.0

First preview. Works with motor 2.0 pre-releases only.

- `MotorDevTools`: a draggable bubble that opens a list of every live Motor controller.
- Pause, replay, scrub and slow down one controller or a group.
- Try another spring or curve on a track, then copy the code.
- `MotorTimeline`: a read-only timeline widget for docs and demos.
- Off in release builds by default. `--dart-define=MOTOR_DEVTOOLS=false` removes the code.
