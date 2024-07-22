import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Useful extensions on [AutoDisposeRef] for caching.
extension AutoDisposeRefCacheX<T> on AutoDisposeRef<T> {
  /// When invoked, makes sure the provider stays alive for at least [duration].
  ///
  /// This timer is only reset when the provider recomputes. So if a listener is
  /// added, remains active for [duration], and then is removed, the provider
  /// will be disposed immediately.
  ///
  // TODO(tim): get rid of this once riverpod has it built-in, https://github.com/rrousselGit/riverpod/issues/1664
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    try {
      onDispose(timer.cancel);
    } catch (_) {
      timer.cancel();
    }
  }

  /// Delays the disposal of this provider by [duration].
  ///
  /// If a listener is added before the delay has passed, the delay is reset.
  // TODO(tim): wait if onCancel gets fixed and called for .read, https://github.com/rrousselGit/riverpod/issues/1665
  @Deprecated('Is broken by .read and will never dispose if not listened to')
  void disposeDelay(Duration duration) {
    final link = keepAlive();
    Timer? timer;

    onCancel(() {
      timer?.cancel();
      timer = Timer(duration, link.close);
    });

    onDispose(() {
      timer?.cancel();
    });

    onResume(() {
      timer?.cancel();
    });
  }
}
