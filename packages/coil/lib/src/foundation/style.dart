import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetState, WidgetStateProperty;

/// The base of every component's style class (`CoilButtonStyle`, …).
///
/// A style is a set of nullable overrides. Null means "use the default",
/// which the component computes from the resolved theme tokens with its
/// style's `fallback`, so a token change flows into every field the app
/// didn't set. Styles layer, lowest to highest (doc/api_guide.md §6):
///
/// 1. `fallback(...)`, derived from tokens;
/// 2. the theme's entry for the style type (`CoilThemeData.components`),
///    set app-wide or for a subtree;
/// 3. the component's own `style:` parameter.
///
/// Each layer is [merge]d onto the one below: the other style's non-null
/// fields win; a `motions` map merges key by key. Styles compare by value
/// through [props], maps included, so a rebuilt map literal is equal.
@immutable
abstract class CoilComponentStyle<S extends CoilComponentStyle<S>>
    with Diagnosticable {
  /// Const constructor for subclasses.
  const CoilComponentStyle();

  /// This style with [other]'s non-null fields on top.
  ///
  /// State-dependent fields merge per state with [mergeStates], so an
  /// override that only names some states keeps the lower layer's colors
  /// for the rest.
  S merge(S? other);

  /// [override] on top of [base], state by state: for a set of states,
  /// [override]'s value when it resolves to non-null, else [base]'s.
  ///
  /// `merge` uses it for every [WidgetStateProperty] field, so a partial
  /// override such as
  /// `WidgetStateProperty.fromMap({WidgetState.hovered: red})`, which
  /// resolves to null at rest, keeps the fallback's rest color instead of
  /// leaving the component without one. The result compares by value, so a
  /// style rebuilt with equal layers stays equal.
  static WidgetStateProperty<T?>? mergeStates<T>(
    WidgetStateProperty<T?>? base,
    WidgetStateProperty<T?>? override,
  ) {
    if (override == null) return base;
    if (base == null) return override;
    return _MergedStateProperty<T>(base, override);
  }

  /// The fields, for value equality.
  @protected
  List<Object?> get props;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType || other is! CoilComponentStyle<S>) {
      return false;
    }
    final a = props;
    final b = other.props;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final (x, y) = (a[i], b[i]);
      if (x is Map && y is Map ? !mapEquals(x, y) : x != y) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    for (final prop in props)
      if (prop is Map)
        Object.hashAllUnordered(
          prop.entries.map((e) => Object.hash(e.key, e.value)),
        )
      else
        prop,
  ]);
}

/// [over] resolved first, [base] where [over] gives null.
@immutable
class _MergedStateProperty<T> implements WidgetStateProperty<T?> {
  const _MergedStateProperty(this.base, this.over);

  final WidgetStateProperty<T?> base;
  final WidgetStateProperty<T?> over;

  @override
  T? resolve(Set<WidgetState> states) =>
      over.resolve(states) ?? base.resolve(states);

  @override
  bool operator ==(Object other) =>
      other is _MergedStateProperty<T> &&
      other.base == base &&
      other.over == over;

  @override
  int get hashCode => Object.hash(base, over);

  @override
  String toString() => 'CoilComponentStyle.mergeStates($base, $over)';
}
