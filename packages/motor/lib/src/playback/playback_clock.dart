/// A controller's logical playback time, driven by ticker elapsed times.
///
/// Tickers restart at zero every time they start, and a controller stops its
/// ticker when it pauses or goes idle. This clock turns those restarting
/// readings into one timeline that continues where it stopped, so track start
/// times recorded on it stay valid across restarts.
///
/// Time only advances while the ticker runs, scaled by [rate]. Because it is
/// fed by ticker elapsed times, Flutter's `timeDilation` applies as well.
class PlaybackClock {
  Duration _now = Duration.zero;
  Duration _base = Duration.zero;
  Duration _tickerBase = Duration.zero;
  Duration _lastTickerElapsed = Duration.zero;
  Duration _runStart = Duration.zero;
  double _rate = 1;

  /// The current position on the timeline.
  Duration get now => _now;

  /// Time since the ticker last started, on this clock.
  Duration get sinceTickerStart => _now - _runStart;

  /// How fast this clock advances relative to the ticker.
  double get rate => _rate;

  set rate(double value) {
    assert(value > 0, 'rate must be greater than zero.');
    _rebase(_lastTickerElapsed);
    _rate = value;
  }

  /// Marks a ticker (re)start: its next elapsed readings begin at zero.
  void tickerStarted() {
    _rebase(Duration.zero);
    _runStart = _now;
  }

  /// Advances to the position matching [tickerElapsed] and returns it.
  ///
  /// Positions are computed from the last rebase rather than accumulated per
  /// frame, so rate changes do not drift and rate 1 matches the ticker
  /// exactly.
  Duration tick(Duration tickerElapsed) {
    _lastTickerElapsed = tickerElapsed;
    final sinceBase = tickerElapsed - _tickerBase;
    return _now = _base + (_rate == 1 ? sinceBase : sinceBase * _rate);
  }

  /// Moves the timeline to [position], for example when scrubbing.
  void seek(Duration position) {
    _runStart += position - _now;
    _now = position;
    _rebase(_lastTickerElapsed);
  }

  void _rebase(Duration tickerElapsed) {
    _base = _now;
    _tickerBase = tickerElapsed;
    _lastTickerElapsed = tickerElapsed;
  }
}
