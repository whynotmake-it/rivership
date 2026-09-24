part of 'track_controller.dart';

/// The [TickerFuture] of one [TrackController] call, resolved by the
/// controller when that call's [tracks] finish or are interrupted.
///
/// Flutter only creates pending ticker futures for a whole [Ticker], so this
/// implements the same contract for a subset of tracks.
class _TrackFuture implements TickerFuture {
  _TrackFuture(this.tracks);

  /// The tracks this future waits for.
  final Set<Track> tracks;

  final _primary = Completer<void>();
  Completer<void>? _secondary;

  /// Null while pending, true once completed, false once canceled.
  bool? _completed;

  void complete() {
    if (_completed != null) return;
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
        null => 'active',
        true => 'complete',
        false => 'canceled',
      }})';
}
