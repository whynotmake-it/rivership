/// The mode in which an animation should loop.
enum LoopMode {
  /// Don't loop the animation.
  none,

  /// The animation will loop from the end back to the start.
  loop,

  /// The animation will play forward and then reverse back to the start.
  pingPong,

  /// The animation will loop seamlessly by treating the first and last values
  /// as identical, creating smooth circular transitions without jarring jumps.
  seamless;

  /// Whether the animation should loop.
  bool get isLooping => this == loop || this == pingPong || this == seamless;
}
