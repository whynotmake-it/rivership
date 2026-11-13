import 'package:coil/src/foundation/adaptive.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/anchor.dart';
import 'package:coil/src/primitives/sheet.dart';
import 'package:flutter/widgets.dart';

/// What kind of overlay is opening, for [CoilAdaptivePopup.presentationOf].
enum CoilOverlayKind {
  /// A dropdown of actions.
  actionMenu,

  /// A menu opened by right-click or long-press.
  contextMenu,

  /// Pick one or several of a list of values.
  select,

  /// A text field with suggestions.
  combobox,

  /// A date or time picker.
  dateTime,
}

/// What [CoilAdaptivePopup.presentationOf] needs to know about an overlay.
@immutable
class CoilOverlayTraits {
  /// Describes an overlay.
  const CoilOverlayTraits({
    required this.kind,
    required this.itemCount,
    this.hasSearch = false,
    this.multiSelect = false,
    this.submenuDepth = 0,
  });

  /// What it is.
  final CoilOverlayKind kind;

  /// How many rows it lists at the top level.
  final int itemCount;

  /// Whether it has a search or filter field.
  final bool hasSearch;

  /// Whether rows toggle independently.
  final bool multiSelect;

  /// How many levels of submenus it nests.
  final int submenuDepth;
}

/// The one place that decides whether a choice overlay is a popover or a
/// sheet, and opens it.
abstract final class CoilAdaptivePopup {
  /// The most rows a phone shows in an anchored touch popover.
  static const shortMenuMaxItems = 8;

  /// Window widths below this are phone-sized (compact width class).
  static const compactWidth = 600.0;

  /// How [traits] should open at [context], decided when it opens.
  ///
  /// First match wins: the component's [override]; a
  /// [CoilAdaptiveScope.presentation]; on the touch tier in a compact window,
  /// the hybrid phone rule ([phonePresentation]); else a popover.
  static CoilPresentation presentationOf(
    BuildContext context, {
    required CoilOverlayTraits traits,
    CoilPresentation? override,
  }) {
    if (override != null) return override;
    if (CoilAdaptiveScope.maybePresentationOf(context) case final pinned?) {
      return pinned;
    }
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    final compact = MediaQuery.sizeOf(context).width < compactWidth;
    return touch && compact
        ? phonePresentation(traits)
        : CoilPresentation.popover;
  }

  /// The hybrid phone rule.
  ///
  /// Short, simple lists stay anchored to what opened them, with touch-sized
  /// rows, like iOS pull-down menus and Android dropdown menus: action
  /// menus, context menus and selects with at most [shortMenuMaxItems] rows,
  /// no search, single selection and at most one submenu level. Everything
  /// that needs room or a keyboard is a sheet: longer lists, search,
  /// multi-select, comboboxes and date/time pickers.
  static CoilPresentation phonePresentation(CoilOverlayTraits traits) {
    final needsRoom =
        traits.kind == CoilOverlayKind.combobox ||
        traits.kind == CoilOverlayKind.dateTime ||
        traits.hasSearch ||
        traits.multiSelect ||
        traits.submenuDepth > 1 ||
        traits.itemCount > shortMenuMaxItems;
    return needsRoom ? CoilPresentation.sheet : CoilPresentation.popover;
  }

  /// Opens [content] anchored to [anchorContext]'s box, or in a sheet, as
  /// [presentation] says. Themes and adaptive pins at [anchorContext] are
  /// carried into the overlay. Completes with the route's result when it
  /// closes.
  ///
  /// [popover] wraps the content in the popover's surface; [sheet] in the
  /// sheet's. Both receive the same [content].
  static Future<T?> show<T>(
    BuildContext anchorContext, {
    required CoilPresentation presentation,
    required WidgetBuilder content,
    required Widget Function(BuildContext context, Widget content) popover,
    required Widget Function(BuildContext context, Widget content) sheet,
    double estimatedHeight = 0,
    double maxHeight = double.infinity,
  }) {
    final navigator = Navigator.of(anchorContext);
    final themes = InheritedTheme.capture(
      from: anchorContext,
      to: navigator.context,
    );
    final motion = CoilTheme.motionOf(anchorContext);
    final Route<T> route;
    switch (presentation) {
      case CoilPresentation.popover:
        final box = anchorContext.findRenderObject()! as RenderBox;
        final overlay = navigator.context.findRenderObject()! as RenderBox;
        final anchor =
            box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
        route = CoilPopoverRoute<T>(
          anchor: anchor,
          minWidth: box.size.width,
          estimatedHeight: estimatedHeight,
          maxHeight: maxHeight,
          enterMotion: motion.standard,
          exitMotion: motion.standardExit,
          capturedThemes: themes,
          builder: (context) => popover(context, content(context)),
        );
      case CoilPresentation.sheet:
        route = CoilSheetRoute<T>(
          motion: motion.gentle,
          barrierColor: CoilSheetPanel.barrierColorOf(anchorContext),
          capturedThemes: themes,
          child: Builder(
            builder: (context) => sheet(context, content(context)),
          ),
        );
    }
    return navigator.push(route);
  }
}
