// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/src/components/dropdown/dropdown_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';

/// Builds a dropdown's trigger. Call `controller.open()` to show the menu.
typedef CoilDropdownTriggerBuilder =
    Widget Function(BuildContext context, CoilPopupController controller);

/// An action menu: [entries] in a popover next to the trigger, or in a
/// sheet on a phone when the menu is long.
///
/// Rows are [CoilAction]s, grouped with [CoilMenuLabel]s and
/// [CoilMenuSeparator]s. A hovering pointer lights rows with a gliding
/// highlight; arrows, Home, End and typing move between rows; Enter or
/// Space picks; Escape and Tab close. Picking an action closes the menu and
/// runs it; a checkable row shows its mark first.
///
/// On a phone, a short menu stays anchored with touch-sized rows and a long
/// one opens as a sheet (see [CoilAdaptivePopup.presentationOf]).
/// [presentation] pins one.
///
/// ```dart
/// CoilDropdown(
///   entries: [
///     CoilAction(label: 'Rename', onPressed: rename),
///     const CoilMenuSeparator(),
///     CoilAction(
///       label: 'Delete',
///       tone: CoilActionTone.destructive,
///       onPressed: delete,
///     ),
///   ],
///   builder: (context, menu) => CoilButton(
///     onPressed: menu.open,
///     child: const Text('Actions'),
///   ),
/// )
/// ```
class CoilDropdown extends StatefulWidget {
  /// Creates a dropdown.
  const CoilDropdown({
    required this.entries,
    required this.builder,
    super.key,
    this.controller,
    this.presentation,
    this.style,
    this.motion,
  });

  /// The rows, headings and separators.
  final List<CoilMenuEntry> entries;

  /// Builds the trigger.
  final CoilDropdownTriggerBuilder builder;

  /// Opens and closes the menu from outside; one is created if null.
  final CoilPopupController? controller;

  /// Pins the presentation instead of deciding it when the menu opens.
  final CoilPresentation? presentation;

  /// Overrides the theme's dropdown style.
  final CoilDropdownStyle? style;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilDropdown> createState() => _CoilDropdownState();
}

class _CoilDropdownState extends State<CoilDropdown> {
  CoilPopupController? _own;

  CoilPopupController get _controller =>
      widget.controller ?? (_own ??= CoilPopupController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  CoilDropdownStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilDropdownStyle.fallback(CoilTheme.of(context), metrics)
          .merge(CoilTheme.styleOf<CoilDropdownStyle>(context))
          .merge(widget.style);

  @override
  Widget build(BuildContext context) {
    final rows = widget.entries.whereType<CoilAction>().length;
    return CoilAdaptivePopup(
      controller: _controller,
      presentation: widget.presentation,
      motion: widget.motion,
      traits: () => CoilOverlayTraits(
        kind: CoilOverlayKind.actionMenu,
        itemCount: rows,
      ),
      maxHeight: _style(context, CoilTheme.metricsOf(context)).maxHeight!,
      content: (context, popup) {
        final theme = CoilTheme.of(context);
        // A sheet is a touch surface whatever the tier.
        final metrics = popup.presentation == CoilPresentation.sheet
            ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
            : CoilTheme.metricsOf(context);
        final style = _style(context, metrics);
        final scroll = CoilScrollAreaStyle.fallback(
          theme,
          metrics,
        ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
        return MotorInspectionScope(
          group: 'CoilDropdown',
          child: CoilActionList(
            entries: widget.entries,
            onClose: popup.close,
            metrics: metrics,
            surface: popup.presentation == CoilPresentation.sheet
                ? theme.colors.surface(3)
                : style.surface!,
            scrollbar: scroll.scrollbarLook,
            fadeExtent: scroll.fadeExtent!,
            highlight: style.highlight,
            pressFill: style.pressFill,
            radius: style.radius,
            motion: widget.motion,
          ),
        );
      },
      popover: (context, content) {
        final metrics = CoilTheme.metricsOf(context);
        final style = _style(context, metrics);
        return CoilPopoverSurface(
          color: style.surface,
          radius: style.radius! + metrics.popupInset,
          minWidth: style.width!,
          child: SizedBox(
            width: metrics.tier == CoilTier.pointer ? style.width : null,
            child: content,
          ),
        );
      },
      sheet: (context, content) => CoilSheetPanel(child: content),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Semantics(
          expanded: _controller.isOpen,
          child: widget.builder(context, _controller),
        ),
      ),
    );
  }
}
