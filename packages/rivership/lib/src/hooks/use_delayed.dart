import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns [before], waits until [delay] has passed, then returns [after].
///
/// If [startDone] is true, [after] will be returned immediately, and only when
/// [keys] have changed will [before] be returned, until [delay] has passed.
T useDelayed<T extends Object>({
  required Duration delay,
  required T before,
  required T after,
  bool startDone = false,
  List<Object?>? keys,
}) {
  final changes = useState(0);
  final timeUp = useState(false);

  useEffect(
    () {
      changes.value++;
      return null;
    },
    keys,
  );

  useEffect(
    () {
      timeUp.value = false;
      final timer = Timer(delay, () {
        timeUp.value = true;
      });
      return timer.cancel;
    },
    [delay, before, after, ...?keys],
  );

  if (startDone && changes.value <= 1 || delay == Duration.zero) {
    return after;
  }
  return timeUp.value ? after : before;
}
