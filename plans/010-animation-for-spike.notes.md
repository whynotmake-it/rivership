# Plan 010 design notes: typed per-track animation views

## Prototype shape and view identity

The prototype adds `TrackController.animationFor<T>(Track<T>)` and returns a
private `_TrackAnimationView<T>`. The view uses
`AnimationWithParentMixin<TrackValueReader>` to delegate listeners and status
directly to the controller, while its `value` getter reads only the selected
track.

Each call returns a new view. The object is stateless apart from its controller
and track references, so caching has no demonstrated performance benefit and
would introduce a cache lifetime tied to every track ever requested. Two views
for the same track consequently have identity equality, which is sufficient for
Flutter animation consumers.

## 1. Status semantics

Whole-controller status is acceptable for the initial API, with a documented
limitation. The prototype test deliberately lets the selected opacity track
finish while a longer scale track remains active: the opacity view continues to
report `AnimationStatus.forward` until the whole controller completes. Despite
that behavior, both `Tween.animate` and `FadeTransition` consume the view
correctly, so the tested framework integrations do not require per-track status.

A future consumer that makes decisions from status listeners, or that needs
reverse curves/direction for one track, may need per-track status. Supporting
that would require:

- exposing changes to `_TrackSlot.isAnimating` per track;
- defining the resting status before start and after completion;
- defining and retaining per-track direction; and
- notifying a view only when that track's status changes.

Direction cannot be inferred from the current slot API. `MotionController`
derives it by checking whether its converter is a
`DirectionalMotionConverter` and comparing the source and target. A per-track
design should establish equivalent behavior rather than guessing from velocity.
No tested consumer exposed a status incompatibility, so this spike does not
trigger the design-review STOP condition.

## 2. Lifetime

A view strongly references its controller and delegates every listener method
to it. It therefore has exactly the parent's usable lifetime; callers should
remove the view from widgets/listeners before disposing the controller, just as
they do for an `AnimationController`. The disposal test removes an
`AnimatedBuilder`, disposes the controller, and completes without a ticker or
listener leak.

There is no lazy subscription to manage: the view adds listeners directly to
the eager parent. Flutter documents `AnimationEagerListenerMixin.dispose` as
making the object unusable. One existing-controller detail deserves follow-up:
the mixin's implementation is empty, and `TrackController.dispose` currently
stops/disposes its ticker and calls `super.dispose()` without explicitly calling
`clearListeners()` or `clearStatusListeners()`. The prototype does not change
that behavior. Production work should verify and, if necessary, harden the
controller's disposal contract separately; views must not be used after parent
disposal.

## 3. Naming

Recommend `animationFor(track)`. It describes a typed animation projection
without suggesting ownership or a new controller, reads naturally at Flutter
call sites (`FadeTransition(opacity: controller.animationFor(opacity))`), and
matches the maintainer's proposed API. Alternatives such as `viewFor`,
`trackAnimation`, or `select` are less explicit about the returned Flutter
`Animation<T>`.

## 4. Uninitialized tracks

Do not eagerly call `_slot(track)` from `animationFor`. Constructing a view
should be side-effect free and preserve the controller's existing lazy slot
creation. Tracks with `initial` already read successfully on first `value`
access; tracks without an initial retain the controller's existing assertion
and `StateError` at the actual read site. Eagerly touching the slot would merely
move that failure to view construction while allocating slots for views that
might never be consumed. The existing error already explains how to provide an
initial value or set/animate the track.

## 5. Velocity

Defer a view-level velocity API. `Animation<T>` has no velocity contract, and
the controller already exposes the typed `velocity(track)` method. Adding
`velocityFor` or a custom animation subtype would complicate a deliberately
small interoperability view without helping `Tween`, transitions, or other
standard `Animation<T>` consumers. Revisit only when a concrete consumer needs
velocity through the view itself.

## 6. Recommendation and production checklist

**Go**, with whole-controller status documented as part of the API. The
prototype preserves typed values through the animation ecosystem, delegates
ticks successfully to `AnimatedBuilder`, composes with `Tween.animate`, and
drives `FadeTransition`. The view is small and uses Flutter's standard parent
animation mechanism.

Productionizing checklist:

- export the API through `lib/motor.dart`;
- add a README section with transition and tween examples;
- add a CHANGELOG entry;
- update the `TrackController` composition documentation;
- retain the focused behavior and integration tests;
- document that status is whole-controller, not per-track;
- verify the listener-clearing behavior of `TrackController.dispose`; and
- benchmark only if there is evidence that allocating new views is material
  before considering a cache.
