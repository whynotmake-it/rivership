import 'dart:async';

import 'package:flutter/widgets.dart';
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

  useEffect(
    () {
      changes.value++;
      return null;
    },
    keys,
  );

  final future = useMemoized(
    () => switch (delay) {
      Duration.zero => Future<void>.value(),
      _ => Future<void>.delayed(delay),
    },
    [delay, before, after, ...?keys],
  );
  final value = useFuture(future);

  if (startDone && changes.value <= 1 || delay == Duration.zero) {
    return after;
  }
  return value.connectionState == ConnectionState.done ? after : before;
}
