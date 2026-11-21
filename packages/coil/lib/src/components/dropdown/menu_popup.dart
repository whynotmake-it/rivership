// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/src/components/dropdown/dropdown_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';

/// The menu `CoilDropdown` and `CoilContextMenu` open: [entries] in a
/// popover, or on a phone in a sheet when the menu is long and a floating
/// panel when it has search.
class CoilMenuPopup extends StatelessWidget {
  /// Creates a menu popup anchored to [child].
  const CoilMenuPopup({
    required this.controller,
    required this.entries,
    required this.kind,
    required this.child,
    super.key,
    this.presentation,
    this.search,
    this.style,
    this.motion,
  });

  /// Opens and closes the menu.
  final CoilPopupController controller;

  /// The rows, headings and separators.
  final List<CoilMenuEntry> entries;

  /// Which menu this is, for the phone presentation rule.
  final CoilOverlayKind kind;

  /// Pins the presentation.
  final CoilPresentation? presentation;

  /// A search field over the rows.
  final CoilMenuSearch? search;

  /// Overrides the theme's dropdown style.
  final CoilDropdownStyle? style;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// The anchor.
  final Widget child;

  CoilDropdownStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilDropdownStyle.fallback(
        CoilTheme.of(context),
        metrics,
      ).merge(CoilTheme.styleOf<CoilDropdownStyle>(context)).merge(style);

  /// The popover surface around a menu's list or a submenu's.
  Widget _surface(BuildContext context, Widget content) {
    final metrics = CoilTheme.metricsOf(context);
    final look = _style(context, metrics);
    return CoilPopoverSurface(
      color: look.surface,
      radius: CoilTheme.radiiOf(context).concentric(
        look.radius!,
        metrics.popupInset,
        innerExtent: metrics.controlHeight,
      ),
      minWidth: look.width!,
      child: SizedBox(
        width: metrics.tier == CoilTier.pointer ? look.width : null,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CoilAdaptivePopup(
    controller: controller,
    presentation: presentation,
    motion: motion,
    traits: () => CoilOverlayTraits(
      kind: kind,
      itemCount: entries
          .where((entry) => entry is CoilAction || entry is CoilSubmenu)
          .length,
      submenuDepth: CoilSubmenu.depthOf(entries),
      hasSearch: search != null,
    ),
    maxHeight: _style(context, CoilTheme.metricsOf(context)).maxHeight!,
    content: (context, popup) {
      final theme = CoilTheme.of(context);
      // A sheet is a touch surface whatever the tier.
      final metrics = popup.presentation.usesSheetPanel
          ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
          : CoilTheme.metricsOf(context);
      final look = _style(context, metrics);
      final scroll = CoilScrollAreaStyle.fallback(
        theme,
        metrics,
      ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
      // In a sheet with search the close button ends the search line,
      // which takes the header's place.
      final searchSheet = popup.presentation.usesSheetPanel && search != null;
      return MotorInspectionScope(
        group: 'CoilMenu',
        child: CoilActionList(
          entries: entries,
          onClose: popup.close,
          onAcknowledge: popup.release,
          metrics: metrics,
          // The sheet paints its own surface; the popover may take the
          // style's.
          surface: popup.presentation.usesSheetPanel ? null : look.surface,
          scrollbar: scroll.scrollbarLook,
          fadeExtent: scroll.fadeExtent!,
          highlight: look.highlight,
          pressFill: look.pressFill,
          radius: look.radius,
          submenu: _surface,
          search: search,
          searchTrailing: searchSheet ? const CoilSheetCloseSlot() : null,
          motion: motion,
        ),
      );
    },
    popover: _surface,
    sheet: (context, content) => search == null
        ? CoilSheetPanel(child: content)
        : CoilSheetPanel(
            close: null,
            child: Padding(
              padding: EdgeInsets.only(
                top: CoilSheetPanel.lineTopOf(
                  context,
                  CoilTheme.of(
                        context,
                      ).metrics
                      .resolve(CoilTier.touch, CoilSize.regular)
                      .controlHeight,
                ),
              ),
              child: content,
            ),
          ),
    child: child,
  );
}
