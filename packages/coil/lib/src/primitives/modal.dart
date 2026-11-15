import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/adaptive_popup.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:coil/src/primitives/sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Where a modal shows.
enum CoilModalPresentation {
  /// Centered over a scrim, springing in with a blur-fade.
  centered,

  /// A bottom sheet that can be dragged away.
  sheet,

  /// A full-height panel that slides in from the start edge, like a
  /// navigation drawer.
  drawer,
}

/// Shows [builder] as a modal above the current route: pushes a
/// [CoilModalRoute] on the nearest navigator.
///
/// [presentation] decides how it shows; null picks a sheet on the touch tier
/// in a compact window and centers it elsewhere. With [dismissible] false,
/// the scrim, Esc, back and dragging don't close it. The future completes
/// with the value passed to `Navigator.pop`.
Future<T?> showCoilModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  CoilModalPresentation? presentation = CoilModalPresentation.centered,
  bool dismissible = true,
  String? barrierLabel,
  CoilMotion? motion,
}) => Navigator.of(context).push(
  CoilModalRoute<T>(
    context: context,
    builder: builder,
    presentation: presentation,
    dismissible: dismissible,
    barrierLabel: barrierLabel,
    motion: motion,
  ),
);

/// A route that shows a modal: centered over a scrim, as a sheet or as a
/// drawer. [showCoilModal], `showCoilDialog`, `showCoilSettingsDialog` and
/// `showCoilCommandMenu` push one.
///
/// Push it yourself, return it from a router's custom route builder, or
/// use a [CoilModalPage] in `Navigator.pages`:
///
/// ```dart
/// Navigator.of(context).push(
///   CoilModalRoute<bool>(
///     context: context,
///     builder: (context) => CoilDialog(title: const Text('Delete?')),
///   ),
/// );
/// ```
///
/// `context` is read once, while the route is created: it picks the
/// presentation when `presentation` is null (a sheet on the touch tier in a
/// compact window, centered elsewhere), the motion tokens, the scrim color
/// and the themes the modal inherits. Centered modals and drawers spring in
/// on the theme's `gentle` token and out on `gentleExit`; sheets use
/// `gentle`. With `dismissible` false, the scrim, Esc, back and dragging
/// don't close it.
sealed class CoilModalRoute<T> implements PopupRoute<T> {
  /// Creates the route for [presentation], or for the presentation that
  /// fits [context] when it's null.
  factory CoilModalRoute({
    required BuildContext context,
    required WidgetBuilder builder,
    CoilModalPresentation? presentation,
    bool dismissible = true,
    String? barrierLabel,
    CoilMotion? motion,
    RouteSettings? settings,
  }) {
    final navigator = Navigator.of(context);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final barrierColor = CoilSheetPanel.barrierColorOf(context);
    final resolved = presentation ?? adaptivePresentationOf(context);
    Widget content(BuildContext context) => PopScope(
      canPop: dismissible,
      child: Builder(builder: builder),
    );
    return switch (resolved) {
      CoilModalPresentation.sheet => _CoilModalSheetRoute<T>(
        motion: tokens.gentle,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        capturedThemes: themes,
        settings: settings,
        child: Builder(builder: content),
      ),
      CoilModalPresentation.centered => _CoilPanelRoute<T>(
        presentation: resolved,
        enter: tokens.gentle,
        exit: tokens.gentleExit,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        settings: settings,
        builder: (context) => themes.wrap(content(context)),
        transition: (animation, child) =>
            CoilBlurFade(presence: animation, scale: 0.97, child: child),
      ),
      CoilModalPresentation.drawer => _CoilPanelRoute<T>(
        presentation: resolved,
        enter: tokens.gentle,
        exit: tokens.gentleExit,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        settings: settings,
        builder: (context) => themes.wrap(
          Align(
            alignment: AlignmentDirectional.centerStart,
            // Slides by the panel's width, not the window's.
            child: _SlideFromStart(
              presence: ModalRoute.of(context)!.animation!,
              child: content(context),
            ),
          ),
        ),
        transition: (animation, child) => child,
      ),
    };
  }

  /// How this modal shows.
  CoilModalPresentation get presentation;

  /// The presentation a modal at [context] gets when none is given: a
  /// sheet on the touch tier in a compact window, centered elsewhere.
  static CoilModalPresentation adaptivePresentationOf(BuildContext context) =>
      CoilTheme.tierOf(context) == CoilTier.touch &&
          MediaQuery.sizeOf(context).width < CoilAdaptivePopup.compactWidth
      ? CoilModalPresentation.sheet
      : CoilModalPresentation.centered;

  /// How the [CoilModalRoute] around [context] shows, or null outside one.
  /// Content reads it to fit its presentation, such as a dialog stacking
  /// its actions in a sheet.
  static CoilModalPresentation? presentationOf(BuildContext context) =>
      switch (ModalRoute.of(context)) {
        final CoilModalRoute<Object?> route => route.presentation,
        _ => null,
      };
}

/// A [Page] that shows [child] in a [CoilModalRoute], for
/// `Navigator.pages` and routers built on it.
///
/// [presentation], [dismissible], [barrierLabel] and [motion] are read when
/// the route is created, from the navigator's context; a changed [child]
/// rebuilds the open modal. Popping it (the scrim, Esc, back, a drag, or
/// `Navigator.pop`) calls the navigator's `onDidRemovePage`.
class CoilModalPage<T> extends Page<T> {
  /// Creates a page that shows [child] as a modal.
  const CoilModalPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    this.presentation,
    this.dismissible = true,
    this.barrierLabel,
    this.motion,
  });

  /// The modal's content, such as a `CoilDialog`.
  final Widget child;

  /// How it shows; null picks a sheet on the touch tier in a compact
  /// window and centers it elsewhere.
  final CoilModalPresentation? presentation;

  /// Whether the scrim, Esc, back and dragging close it.
  final bool dismissible;

  /// The scrim's label for screen readers.
  final String? barrierLabel;

  /// Motion tokens for the modal, instead of the theme's.
  final CoilMotion? motion;

  @override
  Route<T> createRoute(BuildContext context) => CoilModalRoute<T>(
    context: context,
    settings: this,
    presentation: presentation,
    dismissible: dismissible,
    barrierLabel: barrierLabel,
    motion: motion,
    // The latest page's child, so updating the page updates the modal.
    builder: (context) =>
        (ModalRoute.settingsOf(context)! as CoilModalPage<T>).child,
  );
}

/// A sheet [CoilModalRoute].
class _CoilModalSheetRoute<T> extends CoilSheetRoute<T>
    implements CoilModalRoute<T> {
  _CoilModalSheetRoute({
    required super.child,
    required super.motion,
    required super.barrierColor,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierDismissible,
    super.settings,
  });

  @override
  CoilModalPresentation get presentation => CoilModalPresentation.sheet;
}

/// A centered or drawer [CoilModalRoute]: its panel springs in and out on
/// Motor.
class _CoilPanelRoute<T> extends RawDialogRoute<T>
    implements CoilModalRoute<T> {
  _CoilPanelRoute({
    required this.presentation,
    required WidgetBuilder builder,
    required this.enter,
    required this.exit,
    required Color barrierColor,
    required super.barrierDismissible,
    required Widget Function(Animation<double> animation, Widget child)
    transition,
    super.barrierLabel,
    super.settings,
  }) : super(
         barrierColor: barrierColor,
         pageBuilder: (context, _, _) => builder(context),
         transitionBuilder: (context, animation, _, child) =>
             transition(animation, child),
       );

  @override
  final CoilModalPresentation presentation;

  final Motion enter;
  final Motion exit;

  @override
  Simulation createSimulation({required bool forward}) =>
      (forward ? enter : exit).createSimulation(
        start: animation?.value ?? (forward ? 0 : 1),
        end: forward ? 1 : 0,
      );
}

/// Slides [child] in from the start edge by its own width as [presence]
/// goes from 0 to 1.
class _SlideFromStart extends StatelessWidget {
  const _SlideFromStart({required this.presence, required this.child});

  final Animation<double> presence;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ListenableBuilder(
      listenable: presence,
      builder: (context, child) => FractionalTranslation(
        translation: Offset((1 - presence.value) * (rtl ? 1 : -1), 0),
        child: child,
      ),
      child: child,
    );
  }
}
