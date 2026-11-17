import 'package:coil/dropdown.dart';
import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:coil/tabs.dart';
import 'package:coil/toggle_group.dart';
import 'package:coil_glass/src/glass_style.dart';
import 'package:flutter/widgets.dart';

/// Adapts the coil components in [child] to sit on glass.
///
/// `CoilGlass` wraps its content in one; use it directly for content that
/// sits on glass you composed yourself. It changes no component, only the
/// subtree's theme:
///
/// * selection platters (tabs, toggle groups) and row highlights become a
///   thin wash of the foreground, so the glass shows through instead of a
///   grey slab sitting on it;
/// * fields and menus drop their opaque fills: the glass is the surface;
/// * whatever opens from inside opens a popover step above.
class CoilOnGlass extends StatelessWidget {
  /// Adapts [child] to glass of [variant].
  const CoilOnGlass({
    required this.child,
    super.key,
    this.variant = CoilGlassVariant.regular,
  });

  /// The content on the glass.
  final Widget child;

  /// The glass underneath.
  final CoilGlassVariant variant;

  /// The selection platter on glass: Apple's tab bar platter is about 8%
  /// black over light glass and a lighter wash over dark glass.
  static Color platterOf(CoilColors colors) => colors.foreground.withValues(
    alpha: colors.brightness == Brightness.dark ? 0.14 : 0.08,
  );

  @override
  Widget build(BuildContext context) => CoilTheme.override(
    transform: (theme) {
      final platter = platterOf(theme.colors);
      const clear = Color(0x00000000);
      return theme
          .withComponentStyle(CoilTabsStyle(pill: platter))
          .withComponentStyle(CoilToggleGroupStyle(selection: platter))
          .withComponentStyle(
            const CoilInputStyle(
              fill: WidgetStatePropertyAll(clear),
              border: WidgetStatePropertyAll(clear),
            ),
          )
          .withComponentStyle(
            CoilDropdownStyle(surface: clear, highlight: platter),
          );
    },
    child: CoilSurface.scope(
      offset: CoilSurface.popoverOffset,
      child: child,
    ),
  );
}
