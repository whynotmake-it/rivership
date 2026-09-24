## 0.1.0

- Add a floating bubble that follows drags, flings with its release
  velocity, and settles on the nearest side of the screen.
- Expand the bubble into a list of every live Motor controller, named by its
  `debugLabel`, with a numbered fallback and a hint to add a label.
- Add a controller view with play/pause, replay, controller-local playback
  speed, and a live timeline that scrubs on drag or tap. The timeline shows
  motions, holds, and sync waits per track, releases sync barriers the way
  playback does, and pages through loops one cycle at a time.
- Add session-only motion overrides per track (spring, ease, or linear, with
  duration and bounce) that replay the latest plan immediately and are undone
  when the tools are disabled.
- Animate the tools themselves with Motor, use neutral styling that follows
  the platform's light or dark mode, and depend on neither Material nor
  Cupertino.
- Show a summary lane first and unfold tracks and the motion editor on tap.
  Tune springs on a duration × bounce graph with a live preview and copyable
  code, and offer the app's own motions with `MotorDevTools(motions:)`.
  Graph changes apply on release without replaying the controller.
- Guess names for unlabeled controllers and tracks in debug builds.
- Group controllers with `MotorInspectionScope(group:)` or `inspectionGroup`
  into one row with shared pause, replay, speed and motion that also apply
  to later members. Hide controllers with `inspectable: false`. Merge
  same-name controllers and fold never-played ones.
- Add `MotorTimeline`, a read-only timeline widget.
- Mark controllers the tools changed, count them on the bubble, and undo
  changes with Reset on a controller or group page or "Reset all". Pausing and
  scrubbing resume when their page is left. The list pins changed
  controllers in a Modified section and folds controllers with a muted
  ticker into a Muted section.
- Drag the open panel from its header or background, and minimize it back
  into the bubble.
- Support opt-in production use; when disabled, the inspection registry is
  not attached. `--dart-define=MOTOR_DEVTOOLS=false` removes the tools and
  motor's inspection hooks from a build.
