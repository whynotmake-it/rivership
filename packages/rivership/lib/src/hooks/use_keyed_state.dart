import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Behaves exactly the same as [useState], but allows for setting optional
/// [keys] to trigger state rebuilds.
///
/// [Relevant `flutter_hooks` issue](https://github.com/rrousselGit/flutter_hooks/issues/441)
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///     final page = useState(pageController.initialPage);
///     return PageView(
///        controller: pageController,
///        onPageChanged: (value) => page.value = value,
///       //  ...
///     );
/// }
/// ```
///
/// See also:
///  * [useState]
///  * [ValueNotifier]
///  * [useStreamController], an alternative to [ValueNotifier] for state.
ValueNotifier<T> useKeyedState<T>(
  T initialData, {
  required List<Object?> keys,
}) {
  return use(_StateHook(initialData: initialData, keys: keys));
}

class _StateHook<T> extends Hook<ValueNotifier<T>> {
  const _StateHook({
    required this.initialData,
    super.keys,
  });

  final T initialData;

  @override
  _StateHookState<T> createState() => _StateHookState();
}

class _StateHookState<T> extends HookState<ValueNotifier<T>, _StateHook<T>> {
  late final _state = ValueNotifier<T>(hook.initialData)
    ..addListener(_listener);

  @override
  void dispose() {
    _state.dispose();
  }

  @override
  ValueNotifier<T> build(BuildContext context) => _state;

  void _listener() {
    setState(() {});
  }

  @override
  Object? get debugValue => _state.value;

  @override
  String get debugLabel => 'useState<$T>';
}
