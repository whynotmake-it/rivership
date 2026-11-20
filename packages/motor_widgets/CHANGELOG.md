## 0.1.0-dev.1

> Note: This release has breaking changes.

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

 - **BREAKING** **FEAT**(motor_widgets): spring versions of Flutter's implicit animation widgets (#350).

    * feat(motor)!: motor 2.0
    
    Motor 2.0 adds a multi-track animation engine and rebuilds the 1.x API on
    
    
    - Tracks, steps (to, at, hold, free, sync) and timelines, played by
      TrackController, PhaseTrackController, TrackBuilder and PhaseTrackBuilder,
      with pause, resume and scrubbing on one playback timeline.
    - A timing model with two moments: a motion has ended once its duration
      has passed, and has settled once it is at rest on its target. By default
      the next step waits until the previous one has settled; with
      until: WaitUntil.ended it takes over at the duration. Every controller
      call returns a MotionFuture: awaiting it waits until settled, and its
      ended completes at the duration.
    - Staggering: animations take a delay, and a redirect hands the running
      motion over, so a delayed item keeps its momentum.
    - Converters can declare their dimensions (linear, periodic, bounded):
      MotionConverter.angle takes the short way round, and color channels clamp
      only the shown value.
    - MotionController, the bounded, single and sequence controllers and the
      motion builders run on the new engine. The sequence API is deprecated.
    - Sealed motions with FreeMotion and Motion.instant, simulations that
      report when they settle (SettlingSimulation), status by direction,
      velocity tracking, an experimental inspection API, fixed tick rates and a
      benchmark suite.
    - Seeded adversarial tests that fuzz playback, controllers and builders.
    
    
    springs snapping to their end value, status by direction, a graceful stop
    completing futures, and MotionFuture return types.
    packages/motor/CHANGELOG.md lists every change under Breaking changes, and
    packages/motor/MIGRATION.md shows how to migrate.
    
    
    
    
    * feat(motor_devtools): add in-app inspection and motion tuning tools for motor
    
    MotorDevTools wraps an app with a draggable bubble that opens a panel of
    live motor controllers. Each controller has play, pause, replay and speed
    controls, a live timeline that scrubs on drag, and a motion editor whose
    session-only edits can be copied as code. MotorTimeline is a read-only
    timeline widget, and the const kMotorDevTools flag removes the tools from a
    build.
    
    
    
    * feat(motor_example): rebuild the gallery as seven one-idea chapters
    
    The motor example is a home screen plus seven chapters (toggle, retarget,
    steps, sync, phases, scrub, card stack), each showing its code and live
    timeline, wrapped in MotorDevTools. The new unpublished example_design
    package shares the theme, widgets and logo with the stupid_simple_sheet
    example. apps/example wraps its router in MotorDevTools and registers the
    bundled font licenses.
    
    
    
    * refactor(motor)!: move MotionPadding and PaddingExtended to motor_widgets
    
    Start packages/motor_widgets, the home for Motor-driven versions of
    Flutter's implicit animation widgets, and move MotionPadding,
    PaddingExtended/RenderPaddingExtended and their tests into it.
    package:motor no longer exports them.
    
    MotionPadding gains onEnd and debugLabel, and its child is optional, as in
    AnimatedPadding. stupid_simple_sheet now gets PaddingExtended from
    motor_widgets. motor's CHANGELOG, MIGRATION and README describe the move.
    
    
    
    * feat(motor_widgets): add spring-driven implicit animation widgets
    
    Add MotionOpacity, MotionScale, MotionRotation and MotionSlide (a
    MotionBuilder with a converter each), MotionAlign and MotionPositioned,
    MotionContainer and MotionSize. Each takes the parameters of the Flutter
    widget it replaces, with motion instead of duration and curve, plus
    tickerRate and debugLabel.
    
    MotionAlign, MotionPositioned and MotionContainer put one track per
    property on one TrackBuilder, so changing one property never disturbs
    another in flight. As in Flutter, a property that goes from null to a
    value starts there. MotionContainer builds Container's tree with
    PaddingExtended so padding and margin may overshoot below zero.
    
    MotionSize is a render object that springs its size toward its child's
    with a MotionController and keeps its velocity when the child's size
    changes mid-flight.
    
    Tests cover settling exactly, velocity continuity on retarget,
    Motion.instant() and a source check that lib has no AnimationController,
    tween or curve.
    
    
    
    * feat(motor_widgets): add MotionTransition, MotionSwitcher and MotionSizeSwitcher
    
    MotionTransition is an immutable value that maps a presence value (0 gone,
    1 present, overshoot allowed) to a widget, with .fade, .scale, .slide,
    .translate, .blur and .blurFade presets that compose with +. The blur is an
    ImageFiltered that is turned off at zero, so the tree keeps its shape.
    
    MotionSwitcher replaces AnimatedSwitcher: every child has a presence spring
    (a SingleMotionBuilder), motion going in and exitMotion going out. A child
    whose key comes back while leaving turns around from its presence and
    velocity and keeps its state. MotionSizeSwitcher wraps it in MotionSize,
    replacing rivership's AnimatedSizeSwitcher, including immediateResize.
    
    Goldens show blurFade, scale and slide at several presence values.
    
    
    
    * docs(motor_widgets): add README and CHANGELOG
    
    
    
    * refactor(motor_widgets)!: give MotionSwitcher AnimatedSwitcher's builder API
    
    motor_widgets now only holds widgets that match Flutter's own, so
    MotionTransition and its presets (including blurFade) are removed; they
    move to the coil design system.
    
    MotionSwitcher and MotionSizeSwitcher take AnimatedSwitcher's
    transitionBuilder and layoutBuilder, defaulting to its builders. Each
    child's Animation<double> is a SingleMotionController presence spring
    (motion in, exitMotion out), so Flutter's transitions work unchanged and
    a returning key reverses with its velocity. The animation is not clamped:
    FadeTransition clamps the alpha it paints, and scale or slide transitions
    overshoot, which is the bounce.
    
    
    
    * feat(motor_widgets): per-track motions keyed by typed track classes
    
    MotionContainer, MotionAlign and MotionPositioned declare their tracks as
    static finals on MotionContainerTrack, MotionAlignTrack and
    
    constructor, so `motions: Map<MotionContainerTrack<Object>, Motion>?`
    only accepts that widget's tracks and dot shorthand works
    (`motions: {.color: .snappySpring()}`). `motion` stays the default for
    every track. Motions compare by value, so a rebuilt map literal redirects
    nothing. README and CHANGELOG describe the pattern.
    
    
    
    * fix(motor_widgets)!: address review findings
    
    - MotionSwitcher removes a leaving child on its dismissed status, so a
      motion change mid-exit no longer leaks it.
    - RenderMotionSize drops its layout flag (motor's stop no longer
      notifies) and becomes private.
    - Directional values resolve before animating; a change of text
      direction jumps. MotionPadding runs on the shared track builder and
      takes any EdgeInsetsGeometry.
    - MotionSizeSwitcher requires motion, takes AlignmentGeometry, and
      passes a null child through.
    - One onEnd listener helper; shared field docs as templates.
    - Tests read geometry, and cover onEnd on mount, tickerRate, direction
      flips, immediateResize and unmounting mid-flight.
    
    
    
    * docs(motor_widgets): list differences from Flutter, tighten README and CHANGELOG
    
    
    
    * fix(motor_widgets): MotionSizeSwitcher keeps leaving children's layout; add sizeMotion
    
    With immediateResize, leaving children sat in Positioned.fill, so they were
    laid out at the new, animating size: wrapping text reflowed while it faded
    and ignored alignment. A small render object now sizes to the MotionSize
    around the current child and lays leaving children out with the switcher's
    own constraints, placed by alignment and clipped by clipBehavior.
    
    sizeMotion gives the size its own spring (defaults to motion), so the size
    can follow a spatial token while the children fade on another.
    
    
    
    * refactor(motor_widgets): ImplicitTrackBuilder maps onto TrackBuilder's initialValues
    
    TrackBuilder now applies initialValues to tracks it first sees after
    mount, so the per-property from:/jumped-to bookkeeping is gone. A
    property set for the first time starts at its value, and a new text
    direction jumps every property through restartTrigger.
    
    
    
    * fix(motor_widgets): remove a MotionSwitcher child replaced before its first frame
    
    A child still at presence 0 that is replaced settles at once with
    status completed, not dismissed, so it was never removed and stayed
    mounted for good. Remove a leaving child on any settled status, make
    removal idempotent, and iterate over a copy when redirecting leaving
    children. Document that exitMotion has to settle.
    
    
    
    
    * fix(motor_widgets): turn Matrix4 rotations the short way
    
    Matrix4.decompose returns a quaternion whose sign flips between -120°
    and -121° (240°), so interpolating its components, as Matrix4Tween
    does, spun a rotation from -100° to -140° the long way through 0°.
    Matrix4MotionConverter now picks the w >= 0 quaternion, with a fixed
    sign at exactly half a turn, so a rotation goes the short way unless
    that passes 180°. Documented, with MotionRotation for longer spins.
    
    
    
    
    * fix(motor_widgets): reset MotionSize's child offset under tight constraints
    
    Under tight constraints MotionSize returned early without positioning
    the child, so a child that had been aligned mid-flight kept its stale
    offset and was painted off the box. Put it at the origin, where it
    fills the size.
    
    
    
    
    * fix(motor_widgets): animate between MotionContainer color and decoration color
    
    AnimatedContainer treats color as a shorthand for
    BoxDecoration(color: color), so switching from one to the other
    animates; MotionContainer kept them on separate tracks and snapped.
    Both now share MotionContainerTrack.color; decorationColor is the same
    track.
    
    
    
    
    * fix(motor_widgets): take an AlignmentGeometry in MotionScale and MotionRotation
    
    As AnimatedScale and AnimatedRotation do, and as MotionSize, MotionAlign
    and MotionSizeSwitcher already did. Source-compatible.
    
    
    
    
    * fix(motor_widgets): implement computeDryBaseline for MotionSizeSwitcher and MotionSize
    
    MotionSizeSwitcher(immediateResize: true)'s render object overrode
    computeDryLayout but not computeDryBaseline, which asserts when a
    baseline-aligned parent computes its dry layout. MotionSize now offsets
    its dry baseline by the alignment, as AnimatedSize does. Clarify which
    constraints leaving children get with immediateResize, and that
    toggling it reparents the child.
    
    
    
    
    * docs(motor_widgets): note how MotionContainer turns a transform's rotation
    
    
    
    
    * refactor(motor_widgets): simplify ImplicitTrackBuilder and explain its rules
    
    Spell out what the helper adds to TrackBuilder: Flutter's null rules for
    implicitly animated properties (unset to set starts at the target, set
    to unset drops the property, a new text direction jumps), derived from
    one target per property. Rename tracks/implicit() to targets/target()
    and ImplicitTrack to ImplicitTarget, so call sites read as a property's
    target, and build the TrackBuilder from three comprehensions.
    
    
    
    
    ---------


## 0.1.0-dev.0

 - **FEAT**: first release: spring-driven versions of Flutter's implicit animation widgets.
 - **FEAT**: `MotionOpacity`, `MotionAlign`, `MotionPositioned`, `MotionScale`, `MotionRotation` and `MotionSlide`, the Motor versions of `AnimatedOpacity`, `AnimatedAlign`, `AnimatedPositioned`, `AnimatedScale`, `AnimatedRotation` and `AnimatedSlide`.
 - **FEAT**: `MotionPadding` and `PaddingExtended`, moved here from `motor`. `MotionPadding` gains `onEnd` and `debugLabel`, takes any `EdgeInsetsGeometry`, and its `child` is optional, as in `AnimatedPadding`.
 - **FEAT**: `MotionContainer`, the Motor version of `AnimatedContainer`. Each property is its own track on one `TrackBuilder`, so changing one property never disturbs another in flight.
 - **FEAT**: per-track motions. `MotionContainer`, `MotionAlign` and `MotionPositioned` declare their tracks on `MotionContainerTrack`, `MotionAlignTrack` and `MotionPositionedTrack`, and take `motions: {.color: …}` to override `motion` for single tracks. The keys are typed per widget and the motions compare by value.
 - **FEAT**: `MotionSize`, the Motor version of `AnimatedSize`: a render object that springs its size toward its child's and keeps its velocity when the child's size changes mid-flight.
 - **FEAT**: `MotionSwitcher`: `AnimatedSwitcher` with a presence spring per child. A child that comes back while leaving turns around with its velocity and keeps its state.
 - **FEAT**: `MotionLayoutGroup` and `MotionLayoutItem`. When a rebuild moves an item, it flies from where it was painted to its new place. Items are matched by `id`, so lazy lists need no keys and an item flies into another container of the same group. Scrolling never makes an item fly, and nothing runs in frames without a rebuild.
 - **FEAT**: `MotionDraggable`, moved here from `motor` and rebuilt. The feedback is animated from pickup to landing: an accepted drop flies to the landing site with the draggable's `id`, like a `Hero` to its tag; a rejected one springs back; a drop with nowhere to land plays an exit. Ids are unique per `MotionLayoutGroup`. A landing on a `MotionLayoutItem` hands off to the item's spring once it can be seen, which `handoff` controls. `start: .longPress` replaces `MotionLongPressDraggable`, and `handleOnly` with `MotionDragHandle` starts the drag from a handle. `feedback` and `childWhenDragging` get the measured size, `transitions` animates `scale`, `rotation` and `opacity` per phase, and `MotionDragDetails.morph` lets the feedback turn into its destination. Plain `DragTarget`s work unchanged. `onlyReturnWhenCanceled` and `feedbackMatchesConstraints` are removed.
 - **FEAT**: `MotionReorderable` takes drags over any list, grid, wrap or sliver (`MotionReorderable.sliver`) and tells its builder where they would drop, between `MotionDrop.after` and `MotionDrop.before`. The builder places a `MotionDropGap` or draws a line. `onMove` gets a `MotionMove`, whose `index` counts after the item has left its old place; it covers reorders, drops from other reorderables and screen-reader moves, and may return a `Future` that keeps the drop pending. The drop stays when the drag leaves, and letting go outside drops there, unless `keepsDropOnLeave` is false.
 - **FEAT**: `MotionDragToScroll` scrolls the nearest scroll view below it while a drag is near one of its edges, faster the closer, with a speed that follows a spring. Nested ones scroll the inner one first, and a scroll view that is scrolling keeps going while the drag stays past its edge, unless `outside` is false.
 - **FEAT**: `MotionSizeSwitcher`, a `MotionSwitcher` inside a `MotionSize`, the Motor version of rivership's `AnimatedSizeSwitcher`. Unlike it, `motion` is required, `sizeMotion` sets the size's spring apart from the fade, and with `immediateResize` a leaving child keeps its layout instead of reflowing at the new size.
