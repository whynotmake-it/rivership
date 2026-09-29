part of 'track_controller.dart';

/// The future of one animation started on a controller: `await` it until the
/// animation has settled, or await [ended] until it has ended.
///
/// Two moments matter for an animation:
///
/// - It has **ended** once its last step has ended, so the next animation
///   may take over. A step ends when its `until` condition is reached: by
///   default once it has settled, or with `until: .duration` after its
///   motion's duration, when a spring is nearly at its target and may still
///   be moving. A hold ends after its duration, and a `.at` at its time.
/// - It has **settled** once it is at rest, exactly on its target.
///
/// Awaiting the future itself waits until the animation has settled, like
/// the [TickerFuture] of an [AnimationController]. By default a step ends
/// once settled too, so both coincide. Await [ended] to chain in code the
/// way the step after an `until: .duration` step takes over:
///
/// ```dart
/// await controller.play([.to(1, until: .duration)]).ended; // at 500 ms
/// controller.animateTo(0); // takes over, keeping its velocity
/// ```
///
/// Both follow the same rules when the animation is interrupted. A later
/// call that restarts its tracks, or a stop with `canceled: true`, cancels
/// it: neither completes, and [orCancel] fails with a [TickerCanceled]. A
/// graceful stop ends it right away and lets it settle. A looping animation
/// never ends or settles.
abstract interface class MotionFuture implements TickerFuture {
  /// A future that has already ended and settled, for calls that start
  /// nothing.
  factory MotionFuture.complete() => _TrackFuture.completed();

  /// Completes once this animation has ended: its last step has reached its
  /// `until` condition, while it may still be settling.
  ///
  /// That is when it settles, unless the last step has `until: .duration`
  /// (and a motion with a duration), is a hold or is a `.at`. It never
  /// completes if the animation is canceled first.
  Future<void> get ended;
}

/// The [MotionFuture] of one [TrackController] call, resolved by the
/// controller when that call's [tracks] end, settle or are interrupted.
///
/// Flutter only creates pending ticker futures for a whole [Ticker], so this
/// implements the same contract for a subset of tracks.
class _TrackFuture implements MotionFuture {
  _TrackFuture(this.tracks);

  _TrackFuture.completed() : tracks = const {} {
    complete();
  }

  /// The tracks this future waits for.
  final Set<Track> tracks;

  final _primary = Completer<void>();
  final _ended = Completer<void>();
  Completer<void>? _secondary;

  /// Null while pending, true once completed, false once canceled.
  bool? _completed;

  @override
  Future<void> get ended => _ended.future;

  /// Whether [ended] has completed.
  bool get hasEnded => _ended.isCompleted;

  void end() {
    if (_completed != null || _ended.isCompleted) return;
    _ended.complete();
  }

  void complete() {
    if (_completed != null) return;
    end();
    _completed = true;
    _primary.complete();
    _secondary?.complete();
  }

  void cancel() {
    if (_completed != null) return;
    _completed = false;
    _secondary?.completeError(const TickerCanceled());
  }

  @override
  Future<void> get orCancel {
    final secondary = _secondary ??= Completer<void>();
    if (!secondary.isCompleted) {
      switch (_completed) {
        case true:
          secondary.complete();
        case false:
          secondary.completeError(const TickerCanceled());
        case null:
          break;
      }
    }
    return secondary.future;
  }

  @override
  void whenCompleteOrCancel(VoidCallback callback) {
    void thunk(Object? value) => callback();
    orCancel.then<void>(thunk, onError: thunk);
  }

  @override
  Stream<void> asStream() => _primary.future.asStream();

  @override
  Future<void> catchError(Function onError, {bool Function(Object)? test}) =>
      _primary.future.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(void value) onValue, {
    Function? onError,
  }) =>
      _primary.future.then<R>(onValue, onError: onError);

  @override
  Future<void> timeout(
    Duration timeLimit, {
    FutureOr<void> Function()? onTimeout,
  }) =>
      _primary.future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<void> whenComplete(dynamic Function() action) =>
      _primary.future.whenComplete(action);

  @override
  String toString() => '${describeIdentity(this)}('
      '${switch (_completed) {
        null => _ended.isCompleted ? 'ended' : 'active',
        true => 'complete',
        false => 'canceled',
      }})';
}
