import 'package:flutter/widgets.dart' show WidgetState, WidgetStateProperty;

/// A simplified version of [WidgetStateProperty] that purposefully trades
/// flexibility for simplicity.
class SimpleWidgetStates<T> extends WidgetStateProperty<T> {
  /// Creates a [SimpleWidgetStates] with the given states.
  SimpleWidgetStates.from({
    required this.normal,
    this.focused,
    this.pressed,
    this.disabled,
    this.dragged,
  });

  /// The normal value when no specific state is active.
  final T normal;

  /// The value when the widget is pressed.
  ///
  /// If not given, this will revert to [normal].
  final T? pressed;

  /// The value when the widget has the focus.
  ///
  /// If not given, this will try to use [pressed], if that's not given it will
  /// revert to [normal].
  final T? focused;

  /// The value while the widget is disabled.
  ///
  /// If not given, this will revert to [normal].
  final T? disabled;

  /// The value while the widget is dragged.
  ///
  /// If not given, this will try to use [pressed], if that's not given it will
  /// revert to [normal].
  final T? dragged;

  @override
  T resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.dragged)) {
      return dragged ?? pressed ?? normal;
    }
    if (states.contains(WidgetState.pressed)) {
      return pressed ?? normal;
    }
    if (states.contains(WidgetState.focused)) {
      return focused ?? pressed ?? normal;
    }
    if (states.contains(WidgetState.disabled)) {
      return disabled ?? normal;
    }
    return normal;
  }
}
