import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
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

/// Shows [builder] as a modal above the current route, [presentation]
/// deciding how.
///
/// Centered modals and drawers spring in on the theme's `gentle` token and
/// out on `gentleExit`; sheets use `gentle`. With [dismissible] false, the
/// scrim, Esc, back and dragging don't close it. Themes from [context]
/// carry over into the modal. The future completes with the value passed
/// to `Navigator.pop`.
Future<T?> showCoilModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  CoilModalPresentation presentation = CoilModalPresentation.centered,
  bool dismissible = true,
  String? barrierLabel,
  CoilMotion? motion,
}) {
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final tokens = CoilTheme.motionOf(context, override: motion);
  final barrierColor = CoilSheetPanel.barrierColorOf(context);
  Widget content(BuildContext context) => PopScope(
    canPop: dismissible,
    child: Builder(builder: builder),
  );

  return switch (presentation) {
    CoilModalPresentation.sheet => navigator.push(
      CoilSheetRoute<T>(
        motion: tokens.gentle,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        capturedThemes: themes,
        child: Builder(builder: content),
      ),
    ),
    CoilModalPresentation.centered => navigator.push(
      _CoilModalRoute<T>(
        enter: tokens.gentle,
        exit: tokens.gentleExit,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        builder: (context) => themes.wrap(content(context)),
        transition: (animation, child) =>
            CoilBlurFade(presence: animation, scale: 0.97, child: child),
      ),
    ),
    CoilModalPresentation.drawer => navigator.push(
      _CoilModalRoute<T>(
        enter: tokens.gentle,
        exit: tokens.gentleExit,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
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
    ),
  };
}

/// A centered modal route whose panel springs in and out on Motor.
class _CoilModalRoute<T> extends RawDialogRoute<T> {
  _CoilModalRoute({
    required WidgetBuilder builder,
    required this.enter,
    required this.exit,
    required Color barrierColor,
    required super.barrierDismissible,
    required Widget Function(Animation<double> animation, Widget child)
    transition,
    super.barrierLabel,
  }) : super(
         barrierColor: barrierColor,
         pageBuilder: (context, _, _) => builder(context),
         transitionBuilder: (context, animation, _, child) =>
             transition(animation, child),
       );

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
