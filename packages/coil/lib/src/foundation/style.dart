import 'package:flutter/foundation.dart';

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
  S merge(S? other);

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
