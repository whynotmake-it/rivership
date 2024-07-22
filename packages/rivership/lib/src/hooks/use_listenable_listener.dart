import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A hook that adds a listener to a [Listenable] and removes it when the
/// widget is disposed.
///
/// [listenable] can be null, in which case the listener will not be added.
/// [keys] can be used to control when the listener is added and removed.
///
/// Example usage:
/// ```dart
/// final textEditingController = useTextEditingController();
/// useListenableListener(textEditingController, () {
///   // This could be you setting a state variable, or logging something.
///   print(textEditingController.text);
/// });
/// ```
void useListenableListener<T extends Listenable>(
  T? listenable,
  VoidCallback listener, {
  List<Object?>? keys,
}) {
  useEffect(
    () {
      if (listenable != null) {
        listenable.addListener(listener);
      }
      return () => listenable?.removeListener(listener);
    },
    [listenable, listener],
  );
}
