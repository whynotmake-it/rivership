import 'package:flutter/widgets.dart';

/// Closes the coil popup that has focus: a popover, a menu, a select's
/// list, a tooltip, a combobox's list, a drawer's panel. coil maps Escape
/// to it.
///
/// coil's widgets register their own action for it with
/// [CoilDefaultAction]. To change what Escape does inside coil, put an
/// [Actions] entry for this intent above the coil widget (at the app's root
/// for every popup):
///
/// ```dart
/// Actions(
///   actions: {
///     CoilDismissIntent: CallbackAction<CoilDismissIntent>(
///       onInvoke: (_) => confirmBeforeClosing(),
///     ),
///   },
///   child: app,
/// )
/// ```
///
/// A disabled entry leaves coil's action in place, so an app can take
/// over only some of the time.
///
/// It isn't Flutter's [DismissIntent]: a text field and every route
/// already have an action for that one, and the nearest action wins, so a
/// popover's Escape would reach the field's or the route's instead.
class CoilDismissIntent extends Intent {
  /// Creates a dismiss intent.
  const CoilDismissIntent();
}

/// coil's own action for an intent of type [T], which an app can replace.
///
/// A coil widget builds an [Actions] with this action for one of coil's
/// intents ([CoilDismissIntent], `CoilSliderStepIntent`, …), below
/// [context]. When a key maps to the intent, the action resolves in this
/// order:
///
/// 1. An enabled action for [T] that the app put above [context] (an
///    [Actions] widget anywhere up the tree). Actions of outer coil
///    widgets are skipped, so an app's override reaches popups nested in
///    popups.
/// 2. [onInvoke], when [isEnabled] allows it.
/// 3. The next coil widget's action for [T] above [context], as if the key
///    had bubbled up to it: Escape over a trigger whose tooltip is hidden
///    closes the popover around it.
///
/// Like [Action.overridable], but safe to nest: Flutter's version takes the
/// nearest action above as the override, which for nested coil widgets is
/// the outer widget's own default.
///
/// Use it only with coil's intents. Flutter's ([DismissIntent],
/// [ScrollIntent], [DirectionalFocusIntent]) have actions in [WidgetsApp],
/// routes and text fields, which step 1 would mistake for an override.
class CoilDefaultAction<T extends Intent> extends ContextAction<T> {
  /// Creates coil's action for [T] in the widget at [context].
  CoilDefaultAction({
    required this.context,
    required this.onInvoke,
    this._isEnabled,
  });

  /// The coil widget's context: above the [Actions] that holds this
  /// action, where overrides and outer coil actions are looked up.
  final BuildContext context;

  /// coil's behavior for the intent.
  final Object? Function(T intent) onInvoke;

  /// Whether [onInvoke] handles the intent now; null means always.
  final bool Function(T intent)? _isEnabled;

  /// The nearest action for [intent] above [context], coil's or not.
  Action<T>? _above(T intent) =>
      context.mounted ? Actions.maybeFind<T>(context, intent: intent) : null;

  /// The app's action for [intent]: the nearest one above that isn't
  /// coil's.
  Action<T>? _override(T intent) {
    var action = _above(intent);
    while (action is CoilDefaultAction<T>) {
      action = action._above(intent);
    }
    return action;
  }

  /// What handles [intent], per the class docs; null when nothing does.
  /// This action stands for [onInvoke].
  Action<T>? _resolve(T intent, BuildContext? focused) {
    final override = _override(intent);
    if (override != null && _enabled(override, intent, focused)) {
      return override;
    }
    if (_isEnabled?.call(intent) ?? true) return this;
    return switch (_above(intent)) {
      final CoilDefaultAction<T> outer => outer._resolve(intent, focused),
      _ => null,
    };
  }

  static bool _enabled<T extends Intent>(
    Action<T> action,
    T intent,
    BuildContext? context,
  ) => action is ContextAction<T>
      ? action.isEnabled(intent, context)
      : action.isEnabled(intent);

  @override
  bool isEnabled(T intent, [BuildContext? context]) =>
      _resolve(intent, context) != null;

  @override
  bool consumesKey(T intent) => switch (_resolve(intent, null)) {
    null => false,
    final action when identical(action, this) => true,
    final action => action.consumesKey(intent),
  };

  @override
  Object? invoke(T intent, [BuildContext? context]) =>
      switch (_resolve(intent, context)) {
        null => null,
        final action when identical(action, this) => onInvoke(intent),
        final ContextAction<T> action => action.invoke(intent, context),
        final action => action.invoke(intent),
      };
}
