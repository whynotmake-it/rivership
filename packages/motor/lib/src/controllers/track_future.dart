part of 'track_controller.dart';

/// One animation started on a controller, which you can `await` until it has
/// settled, or until it has [ended].
///
/// Two moments matter for an animation:
///
/// - It has **ended** once its steps' time is up: the last step's
///   `duration` has elapsed, so the next animation may take over. A spring
///   is nearly at its target by then and may still be moving.
/// - It has **settled** once it is at rest, exactly on its target.
///
/// Awaiting the run itself waits until it has settled, like the
/// [TickerFuture] of an [AnimationController]. Await [ended] to chain the
/// way a track plan does, where the next step takes over at the previous
/// step's duration:
///
/// ```dart
/// await controller.animateTo(1).ended; // after the spring's duration
/// controller.animateTo(0);             // takes over, keeping its velocity
/// ```
///
/// Both follow the same rules when the animation is interrupted. A later
/// call that restarts its tracks, or a stop with `canceled: true`, cancels
/// it: neither completes, and [orCancel] fails with a [TickerCanceled]. A
/// graceful stop ends it right away and lets it settle. A looping animation
/// never ends or settles.
abstract interface class MotionRun implements TickerFuture {
  /// A run that has already ended and settled, for calls that start nothing.
  factory MotionRun.complete() => _TrackFuture.completed();

  /// Completes once this animation has ended: its last step's duration has
  /// elapsed, while it may still be settling.
  ///
  /// A last step with `untilSettled`, a motion without a duration and a
  /// barrier end when they settle. It never completes if the run is canceled
  /// first.
  Future<void> get ended;
}

/// The [MotionRun] of one [TrackController] call, resolved by the
/// controller when that call's [tracks] end, settle or are interrupted.
///
/// Flutter only creates pending ticker futures for a whole [Ticker], so this
/// implements the same contract for a subset of tracks.
class _TrackFuture implements MotionRun {
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
