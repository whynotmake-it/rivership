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
- Support opt-in production use; when disabled, the inspection registry is
  not attached.
