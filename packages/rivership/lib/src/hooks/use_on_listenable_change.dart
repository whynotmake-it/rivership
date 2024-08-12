import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

// FIXME: In here until `flutter_hooks: 0.21.1` is released.

/// Adds a given [listener] to a [Listenable] and removes it when the hook is
/// disposed.
///
/// As opposed to `useListenable`, this hook does not mark the widget as needing
/// build when the listener is called. Use this for side effects that do not
/// require a rebuild.
///
/// See also:
///  * [Listenable]
///  * [ValueListenable]
///  * [useListenable]
void useOnListenableChange(
  Listenable? listenable,
  VoidCallback listener,
) {
  return use(_OnListenableChangeHook(listenable, listener));
}

class _OnListenableChangeHook extends Hook<void> {
  const _OnListenableChangeHook(
    this.listenable,
    this.listener,
  );

  final Listenable? listenable;
  final VoidCallback listener;

  @override
  _OnListenableChangeHookState createState() => _OnListenableChangeHookState();
}

class _OnListenableChangeHookState
    extends HookState<void, _OnListenableChangeHook> {
  @override
  void initHook() {
    super.initHook();
    hook.listenable?.addListener(_listener);
  }

  @override
  void didUpdateHook(_OnListenableChangeHook oldHook) {
    super.didUpdateHook(oldHook);
    if (hook.listenable != oldHook.listenable) {
      oldHook.listenable?.removeListener(_listener);
      hook.listenable?.addListener(_listener);
    }
  }

  @override
  void build(BuildContext context) {}

  @override
  void dispose() {
    hook.listenable?.removeListener(_listener);
  }

  /// Wraps `hook.listener` so we have a non-changing reference to it.
  void _listener() {
    hook.listener();
  }

  @override
  String get debugLabel => 'useOnListenableChange';

  @override
  Object? get debugValue => hook.listenable;
}
