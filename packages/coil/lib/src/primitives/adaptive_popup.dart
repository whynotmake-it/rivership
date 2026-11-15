import 'dart:async';

import 'package:coil/src/foundation/adaptive.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/anchor.dart';
import 'package:coil/src/primitives/popup_controller.dart';
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

/// Opens [content] from [child]: anchored to it in a [CoilPopover], or in
/// a sheet, as [presentationOf] decides each time it opens.
///
/// [controller] opens and closes it; its `open()` resolves with why it
/// closed. The popover is a descendant of this widget, so its content
/// rebuilds with the owner. The sheet is a route: its content builds from
/// the owner's widget when the sheet builds, but doesn't rebuild with it.
///
/// [popover] wraps the content in the popover's surface and [sheet] in the
/// sheet's; [content] gets the [CoilPopupHandle] so it can close with a
/// reason. A tap outside closes either one with
/// [CoilPopupCloseReason.outsideTap] on tap-up; a sheet dragged away or
/// closed by back reports [CoilPopupCloseReason.dismissed].
class CoilAdaptivePopup extends StatefulWidget {
  /// Creates an adaptive popup anchored to [child].
  const CoilAdaptivePopup({
    required this.controller,
    required this.traits,
    required this.content,
    required this.popover,
    required this.sheet,
    required this.child,
    super.key,
    this.presentation,
    this.maxHeight = double.infinity,
    this.takeFocus = true,
    this.motion,
  });

  /// Opens and closes the popup.
  final CoilPopupController controller;

  /// What the popup is, for [presentationOf]. Called when it opens, so
  /// it can describe what the owner shows then (a count decided in layout).
  final ValueGetter<CoilOverlayTraits> traits;

  /// Pins the presentation instead of deciding it.
  final CoilPresentation? presentation;

  /// The popup's content.
  final Widget Function(BuildContext context, CoilPopupHandle popup) content;

  /// Wraps the content in the popover's surface.
  final Widget Function(BuildContext context, Widget content) popover;

  /// Wraps the content in the sheet's surface.
  final Widget Function(BuildContext context, Widget content) sheet;

  /// The anchor.
  final Widget child;

  /// Maximum popover height.
  final double maxHeight;

  /// Whether the popover takes focus; see [CoilPopover.takeFocus]. A sheet
  /// always does.
  final bool takeFocus;

  /// Motion tokens for the popup's enter and exit, instead of the theme's.
  final CoilMotion? motion;

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

  @override
  State<CoilAdaptivePopup> createState() => _CoilAdaptivePopupState();
}

class _CoilAdaptivePopupState extends State<CoilAdaptivePopup> {
  final _popover = CoilPopoverController(debugLabel: 'CoilAdaptivePopup');

  /// The open popup, if any.
  _Handle? _open;

  /// The last popup shown: an exiting popover still builds with it.
  _Handle? _shown;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(CoilAdaptivePopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      _attach();
    }
  }

  @override
  void dispose() {
    widget.controller.detach();
    final open = _open;
    _open = null;
    open?._ownerGone();
    super.dispose();
  }

  void _attach() => widget.controller.attach(
    open: _show,
    close: (reason) => _open?.close(reason),
  );

  Future<CoilPopupCloseReason> _show(Offset? position) {
    if (_open case final open?) return open.closed;
    final presentation = CoilAdaptivePopup.presentationOf(
      context,
      traits: widget.traits(),
      override: widget.presentation,
    );
    final handle = _Handle(presentation, _closed);
    setState(() => _open = _shown = handle);
    switch (presentation) {
      case CoilPresentation.popover:
        _popover.show(at: position);
      case CoilPresentation.sheet:
        _pushSheet(handle);
    }
    widget.controller.didOpen(handle.closed);
    return handle.closed;
  }

  void _closed(_Handle handle) {
    if (_open != handle) return;
    _popover.hide();
    setState(() => _open = null);
  }

  void _pushSheet(_Handle handle) {
    final navigator = Navigator.of(context);
    final route = CoilSheetRoute<CoilPopupCloseReason>(
      motion: CoilTheme.motionOf(context, override: widget.motion).gentle,
      barrierColor: CoilSheetPanel.barrierColorOf(context),
      // The TapRegion closes on tap-up outside, with its reason.
      barrierDismissible: false,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      child: Builder(
        builder: (context) => TapRegion(
          onTapUpOutside: (_) => handle.close(.outsideTap),
          child: widget.sheet(context, widget.content(context, handle)),
        ),
      ),
    );
    handle._route = route;
    unawaited(
      navigator
          .push(route)
          .then((result) => handle._finish(result ?? .dismissed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return CoilPopover(
      controller: _popover,
      onClose: (reason) => _open?.close(reason),
      maxHeight: widget.maxHeight,
      takeFocus: widget.takeFocus,
      motion: widget.motion,
      popover: (context) => widget.popover(
        context,
        widget.content(context, shown!),
      ),
      child: widget.child,
    );
  }
}

class _Handle implements CoilPopupHandle {
  _Handle(this.presentation, this._onClosed);

  @override
  final CoilPresentation presentation;
  final void Function(_Handle handle) _onClosed;
  final _done = Completer<CoilPopupCloseReason>();

  /// The sheet's route, when it is a sheet.
  Route<CoilPopupCloseReason>? _route;

  @override
  Future<CoilPopupCloseReason> get closed => _done.future;

  void _finish(CoilPopupCloseReason reason) {
    if (_done.isCompleted) return;
    _done.complete(reason);
    _onClosed(this);
  }

  /// The owner left the tree while open: resolve now and take the sheet's
  /// route down once the tree is unlocked again.
  void _ownerGone() {
    if (_done.isCompleted) return;
    _finish(.programmatic);
    final route = _route;
    if (route == null) return;
    scheduleMicrotask(() {
      if (!route.isActive) return;
      route.navigator?.removeRoute(route, CoilPopupCloseReason.programmatic);
    });
  }

  @override
  void close(CoilPopupCloseReason reason) {
    if (_done.isCompleted) return;
    // Resolve now: a popover or sheet keeps animating out, but the popup is
    // closed.
    _finish(reason);
    final route = _route;
    if (route == null || !route.isActive) return;
    final navigator = route.navigator!;
    if (route.isCurrent) {
      navigator.pop(reason);
    } else {
      navigator.removeRoute(route, reason);
    }
  }
}
