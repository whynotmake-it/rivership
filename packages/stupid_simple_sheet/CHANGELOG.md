## 1.0.0-dev.8

> Note: This release has breaking changes.

 - **FEAT**(motor_example): rebuild the gallery as seven one-idea chapters (#325).

    The motor example is a home screen plus seven chapters (toggle, retarget,
    steps, sync, phases, scrub, card stack), each showing its code and live
    timeline, wrapped in MotorDevTools. The new unpublished example_design
    package shares the theme, widgets and logo with the stupid_simple_sheet
    example. apps/example wraps its router in MotorDevTools and registers the
    bundled font licenses.

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


## 1.0.0-dev.7

 - **FIX**(scroll_drag_detector): preserve handoff with custom scroll behaviors (#339).

    * test(scroll_drag_detector): reproduce wrapped behavior crashes
    
    * fix(scroll_drag_detector): preserve handoff with child behavior overrides
    
    ---------


## 1.0.0-dev.6

 - Update a dependency to the latest release.

## 1.0.0-dev.5

 - **FIX**(stupid_simple_sheet): respect keyboard insets in glass sheets (#338).
 - **FIX**(scroll_drag_detector): reach the boundary before drag handoff (#337).

## 1.0.0-dev.4

 - **FIX**: notify `PopScope` when a drag attempts to dismiss a sheet whose
   pop is blocked.

## 1.0.0-dev.3

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: replace `onlyDragWhenScrollWasAtTop` with
   `dragHandoff` on every sheet route. Choose whether a sheet can take over
   only when a gesture starts at the scroll boundary or continuously when the
   gesture reaches it.
 - **FIX**: migrate scroll-to-drag routing to the physical-direction
   `scroll_drag_detector` API.
 - **FEAT**: add the deprecated `LegacySnapPhysics` migration helper for apps
   that need the pre-`1.0.0-dev.1` snapping response.

## 1.0.0-dev.2

 - **DOCS**: update logo.

## 1.0.0-dev.1

> Note: This release has breaking changes.

 - **FIX**: snapping sheets can now be dragged past fully open correctly.
 - **FEAT**: add `DismissalMode` to all sheets which unlocks more complex layouts.

    You can set `DismissalMode` to `.shrink` on a sheet to make it shrink
    instead of slide out while being dismissed or dragged down.
    
    Use this to implement things like a persistant footer that remains
    anchored to the bottom of the screen while the sheet is being dismissed.

 - **DOCS**: document new features in example.
 - **DOCS**: add logo.
 - **DOCS**: redesign entire example.
 - **DOCS**: add example for a glass style shrinking modal.
 - **DOCS**: improve examples and README significantly.
 - **BREAKING** **FIX**: `SheetSnappingConfig.minExtent` now correctly returns the minimum extent that is not zero.
 - **BREAKING** **FEAT**: add `SheetBackground.withTopMargin` constructor and elevate cupertino user interface level in `SheetBackground` by default.
 - **BREAKING** **FEAT**: `SheetBackground` elevates cupertino user interface level.

    by default

 - **BREAKING** **FEAT**: support `SnapPhysics` as part of `SheetShappingConfig`.

    BREAKING CHANGES:
    - the signature of`findTargetSnapPoint` changed. It now requires both a relative and an absolute velocity.
    - the default snap physics have changed to match behavior on mobile platforms better. Snapping points cannot be skipped anymore. Set your `SnappingConfig` to use `FrictionSnapPhysics` to revert to the old behavior

 - **BREAKING** **FEAT**: sheet routes that contain `PopScope.canPop == false` cannot be dragged to close anymore.

## 0.9.1+1

 - **FIX**: dragging up a sheet whose highest snapping point was lower than 1.0 would incorrectly snap it to 1.0.

## 0.9.1

 - **FIX**: incorrect snapping points used for cupertino secondary transitions in some cases.
 - **FEAT**: add option to blur route behind `StupidSimpleGlassSheet` and customize `barrierColor`.

## 0.9.0

> Note: This release has breaking changes.

 - **FEAT**: add `RouteSnapshotMode` that can be used to improve performance.
 - **FEAT**: Add `StupidSimpleGlassSheetRoute` which uses the iOS 26 style.
 - **BREAKING** **REFACTOR**: remove deprecated `topRadius` parameter.
 - **BREAKING** **FEAT**: simplify `SheetSnappingConfig` to only support relative values.

    Remove absolute pixel-based snapping which didn't work correctly.


## 0.8.0+1

 - **FIX**: immediately start clearing overscroll when letting go.

## 0.8.0

> Note: This release has breaking changes.

 - **FIX**: dragging up from a snap point doesn't perform one frame of scroll before transitioning to dragging anymore.
 - **DOCS**: updated docs with more cookbooks and all settings.
 - **BREAKING** **FEAT**: removed clip, background color and shape from `StupidSimpleSheetRoute`.

    Added a `SheetBackground` widget as a replacement.
    Wrap your content in `SheetBackground` to get the same effect as before.
    
    This was done to allow more flexibility in customizing the sheet's appearance.


## 0.7.0

> Note: This release has breaking changes.

 - **FIX**: clip behavior wasn't respected in sheets.
 - **BREAKING** **FEAT**: add `backgroundColor` to `StupidSimpleSheetRoute`.

## 0.6.3

 - **FIX**: improve clipping of overlayed sheets.
 - **FEAT**: add `shape` parameter to `StupidSimpleCupertinoSheetRoute`.

    Deprecated `topRadius` parameter in favor of it.


## 0.6.2+3

 - **FIX**: don't interfere with `pop()` animation while sheet is being dragged.

## 0.6.2+2

 - **FIX**: stop bounce when scrolling down while sheet is at top.

## 0.6.2+1

 - **DOCS**: fixed an incorrect changelog entry.

## 0.6.2

 - **FEAT**: add `topRadius` to cupertino sheet.

    This allows matching the iOS 26.0 appearance more closely

 - **FEAT**: add `originateAboveBottomViewInset` to `StupidSimpleSheet` and its mixin.

## 0.6.1

 - **FEAT**: add `draggable` parameter to sheets that can be used to disable user drags (#206).

## 0.6.0+1

 - **FIX**: `overrideSnappingConfig` and `animateToRelative` could interrupt sheet dismissal and break Navigator (#205).

## 0.6.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: allow overriding the current sheet's snapping config from its controller (#203).

    For this, `effectiveSnappingConfig` was introduced on `StupidSimpleSheetTransitionMixin`, which should be used for all snapping configuration calculations instead of `snappingConfig`.
    If you only set `snappingConfig` and didn't do your own calculations with its values, you don't need to change anything.

## 0.5.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: don't call `Navigator.did[Start|Stop]UserGesture` by default to match Flutter sheets.

    You can restore the old behavior by passing `callNavigatorUserGestureMethods = true` to your sheet route


## 0.4.2

 - **FEAT**: add `StupidSimpleSheetController` that can be used from a sheets subtree for imperative control.

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
