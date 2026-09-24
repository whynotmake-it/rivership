part of 'track_controller.dart';

/// A single track of a [TrackController], viewed as an [Animation].
class _TrackAnimation<T extends Object> extends Animation<T>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  _TrackAnimation(this._controller, this._track);

  final TrackController _controller;
  final Track<T> _track;
  T? _lastValue;
  AnimationStatus _lastStatus = AnimationStatus.dismissed;

  @override
  T get value => _controller.value(_track);

  @override
  AnimationStatus get status => _controller._statusOf(_track);

  @override
  void didStartListening() {
    _lastValue = value;
    _lastStatus = status;
    _controller.addListener(_controllerChanged);
  }

  @override
  void didStopListening() {
    _controller.removeListener(_controllerChanged);
  }

  void _controllerChanged() {
    final value = this.value;
    if (value != _lastValue) {
      _lastValue = value;
      notifyListeners();
    }
    final status = this.status;
    if (status != _lastStatus) {
      _lastStatus = status;
      notifyStatusListeners(status);
    }
  }
}
