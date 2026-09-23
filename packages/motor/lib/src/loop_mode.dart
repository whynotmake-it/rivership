/// The mode in which an animation should loop.
enum LoopMode {
  /// Don't loop the animation.
  none,

  /// The animation will loop from the end back to the start. If no step
  /// provides a target motion, the loop restarts from the initial values
  /// without animating back.
  loop,

  /// The animation will play forward and then reverse back to the start.
  pingPong,

  /// The animation will jump back to its start without animating and play
  /// again. Author the final step to end on the starting value so the jump is
  /// invisible, which makes circular motion (e.g. rotations) seamless.
  seamless;

  /// Whether the animation should loop.
  bool get isLooping => this == loop || this == pingPong || this == seamless;
}
