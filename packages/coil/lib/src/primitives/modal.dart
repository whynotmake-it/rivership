import 'dart:async';
import 'dart:math' as math;

import 'package:coil/src/foundation/colors.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/style.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/adaptive_popup.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:coil/src/primitives/sheet.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

/// Where a modal shows.
enum CoilModalPresentation {
  /// Centered over a scrim, springing in with a blur-fade.
  centered,

  /// A bottom sheet that can be dragged away.
  sheet,

  /// A full-height panel that slides in from the start edge, like a
  /// navigation drawer.
  drawer,

  /// A modal popover: a panel floating inside the window's margins over the
  /// scrim, under the top safe area or centered (`anchor`), above the
  /// keyboard, that a drag on `dismissAxis` throws away.
  ///
  /// It lays out like a sheet (touch rows, a [CoilSheetPanel] with a header
  /// or search line), so search lists on a phone use it: they fill the room
  /// under the top safe area, so the panel's height doesn't follow the
  /// results and the search field doesn't jump as they shrink. See
  /// [CoilModalAnchor].
  floating;

  /// Whether the content lays out in a [CoilSheetPanel] with touch rows: a
  /// [sheet] or a [floating] panel. Dialogs, action bars and search lists
  /// read it to stack their actions and put the close button in the header.
  bool get usesSheetPanel => this == sheet || this == floating;
}

/// Where a [CoilModalPresentation.floating] panel sits and how tall it is.
enum CoilModalAnchor {
  /// Under the top safe area, hugging its content up to the room down to
  /// the keyboard (or the home indicator). The keyboard shrinks the room
  /// from below and never moves the panel. Content that should keep a
  /// stable height, such as a search list whose results change, fills the
  /// room itself (a `SizedBox(height: double.infinity)` takes all of it).
  top,

  /// Centered in the room above the keyboard, hugging its content up to
  /// that room.
  center,
}

/// The animated parts of a [CoilModalRoute], as Motor tracks. Use them as
/// keys of the route's `motions` or [CoilModalStyle.motions].
final class CoilModalTrack<T extends Object> extends Track<T> {
  CoilModalTrack._(super.converter, {required String super.debugLabel});

  /// The panel's blur-fade in and out (all presentations but sheets).
  /// Default motion: `gentle` in, `gentleExit` out.
  static final presence = CoilModalTrack<double>._(
    .single,
    debugLabel: 'CoilModalRoute.presence',
  );

  /// A floating panel settling after a released dismiss drag, back to rest
  /// or away, starting with the release velocity. Default motion:
  /// `standard` back to rest, `standardExit` away.
  static final settle = CoilModalTrack<double>._(
    .single,
    debugLabel: 'CoilModalRoute.settle',
  );
}

/// Overrides for a [CoilModalRoute]. Unset fields come from
/// [CoilModalStyle.fallback].
@immutable
class CoilModalStyle extends CoilComponentStyle<CoilModalStyle> {
  /// Creates a modal style.
  const CoilModalStyle({this.margin, this.motions});

  /// The defaults from [theme]'s tokens.
  // The theme is part of every style's signature.
  // ignore: avoid_unused_constructor_parameters
  factory CoilModalStyle.fallback(CoilThemeData theme) =>
      const CoilModalStyle(margin: 8);

  /// How far a floating panel keeps from the window's sides, the top safe
  /// area, and the keyboard or bottom safe area. 8 by default, as
  /// popovers keep from the window's edge.
  final double? margin;

  /// Springs for the modal's animated parts, keyed by [CoilModalTrack]s:
  /// `{CoilModalTrack.settle: const Motion.bouncySpring()}`. The route's own
  /// `motions:` win over these; these win over the motion tokens. [merge]
  /// combines the maps key by key.
  final Map<CoilModalTrack<Object>, Motion>? motions;

  @override
  CoilModalStyle merge(CoilModalStyle? other) => other == null
      ? this
      : CoilModalStyle(
          margin: other.margin ?? margin,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [margin, motions];
}

/// Shows [builder] as a modal above the current route: pushes a
/// [CoilModalRoute] on the nearest navigator.
///
/// [presentation] decides how it shows; null picks a sheet on the touch tier
/// in a compact window and centers it elsewhere. With [dismissible] false,
/// the scrim, Esc, back and dragging don't close it. The future completes
/// with the value passed to `Navigator.pop`. [anchor], [dismissAxis],
/// [motions] and [style] are for the floating presentation; see
/// [CoilModalRoute].
Future<T?> showCoilModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  CoilModalPresentation? presentation = CoilModalPresentation.centered,
  bool dismissible = true,
  String? barrierLabel,
  CoilMotion? motion,
  CoilModalAnchor anchor = CoilModalAnchor.center,
  Axis? dismissAxis = Axis.horizontal,
  Map<CoilModalTrack<Object>, Motion>? motions,
  CoilModalStyle? style,
}) => Navigator.of(context).push(
  CoilModalRoute<T>(
    context: context,
    builder: builder,
    presentation: presentation,
    dismissible: dismissible,
    barrierLabel: barrierLabel,
    motion: motion,
    anchor: anchor,
    dismissAxis: dismissAxis,
    motions: motions,
    style: style,
  ),
);

/// A route that shows a modal: centered over a scrim, as a sheet, as a
/// drawer or as a floating panel. [showCoilModal], `showCoilDialog`,
/// `showCoilSettingsDialog` and `showCoilCommandMenu` push one.
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
/// and the themes the modal inherits. Centered and drawer modals spring in
/// on the theme's `gentle` token and out on `gentleExit` over
/// the theme's [CoilColors.scrim]; a sheet is a [CoilSheetRoute], on
/// `gentle` both ways over the same scrim. With
/// `dismissible` false, the scrim, Esc, back and dragging don't close it.
///
/// A [CoilModalPresentation.floating] panel floats inside the window's
/// margins ([CoilModalStyle.margin]) over the scrim, above the keyboard,
/// at most [CoilSheetRoute.maxWidth] wide and on a dialog-level surface with
/// a sheet's corners on all four sides, so a [CoilSheetPanel] lays out in
/// it as in a sheet. The `anchor` puts it under the top safe area or centers
/// it; either way it hugs its content up to the room above the keyboard,
/// and content that should keep its height fills that room.
/// Dragging along the `dismissAxis` moves the panel with the finger, tilting
/// it a little around where it was grabbed (horizontally) and letting it
/// recede, while the scrim fades and the panel itself fades late. On release
/// it is thrown away when it would coast past half its extent (friction on
/// its offset and velocity), carrying its velocity out on the `settle`
/// track; otherwise it springs back from that velocity. A scrollable
/// inside hands the drag over only at its edge, so a vertical list keeps
/// scrolling under a horizontal dismiss. A null `dismissAxis`, or a
/// non-dismissible route, has no drag. Motion springs resolve from the
/// route's `motions`, then `style` over the theme's [CoilModalStyle], then
/// the motion tokens.
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
    CoilModalAnchor anchor = CoilModalAnchor.center,
    Axis? dismissAxis = Axis.horizontal,
    Map<CoilModalTrack<Object>, Motion>? motions,
    CoilModalStyle? style,
  }) {
    final navigator = Navigator.of(context);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final theme = CoilTheme.of(context);
    final barrierColor = theme.colors.scrim;
    final look = CoilModalStyle.fallback(
      theme,
    ).merge(CoilTheme.styleOf<CoilModalStyle>(context)).merge(style);
    Motion track(CoilModalTrack<Object> track, Motion token) =>
        CoilTheme.trackMotionOf(
          context,
          track,
          instance: motions,
          styled: look.motions,
          token: token,
        );
    final enter = track(CoilModalTrack.presence, tokens.gentle);
    final exit = track(CoilModalTrack.presence, tokens.gentleExit);
    final resolved = presentation ?? adaptivePresentationOf(context);
    Widget content(BuildContext context) => PopScope(
      canPop: dismissible,
      child: Builder(builder: builder),
    );
    return switch (resolved) {
      CoilModalPresentation.sheet => _CoilModalSheetRoute<T>(
        context: context,
        motion: motion,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        settings: settings,
        child: Builder(builder: content),
      ),
      CoilModalPresentation.centered => _CoilPanelRoute<T>(
        presentation: resolved,
        enter: enter,
        exit: exit,
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
        enter: enter,
        exit: exit,
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
      CoilModalPresentation.floating => _CoilFloatingRoute<T>(
        enter: enter,
        exit: exit,
        settleBack: track(CoilModalTrack.settle, tokens.standard),
        settleAway: track(CoilModalTrack.settle, tokens.standardExit),
        margin: look.margin!,
        anchor: anchor,
        dismissAxis: dismissible ? dismissAxis : null,
        barrierColor: barrierColor,
        barrierDismissible: dismissible,
        barrierLabel: barrierLabel,
        settings: settings,
        wrapThemes: themes.wrap,
        content: content,
      ),
    };
  }

  /// How this modal shows.
  CoilModalPresentation get presentation;

  /// The presentation a modal at [context] gets when none is given: a
  /// sheet on the touch tier in a compact window, centered elsewhere.
  static CoilModalPresentation adaptivePresentationOf(BuildContext context) =>
      CoilAdaptivePopup.isPhone(context)
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
/// [presentation], [dismissible], [barrierLabel], [motion], [anchor],
/// [dismissAxis], [motions] and [style] are read when
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
    this.anchor = CoilModalAnchor.center,
    this.dismissAxis = Axis.horizontal,
    this.motions,
    this.style,
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

  /// Where a floating panel sits; see [CoilModalRoute].
  final CoilModalAnchor anchor;

  /// The axis a drag throws a floating panel away along; null for none.
  final Axis? dismissAxis;

  /// Per-track motions; see [CoilModalStyle.motions].
  final Map<CoilModalTrack<Object>, Motion>? motions;

  /// Overrides the theme's [CoilModalStyle].
  final CoilModalStyle? style;

  @override
  Route<T> createRoute(BuildContext context) => CoilModalRoute<T>(
    context: context,
    settings: this,
    presentation: presentation,
    dismissible: dismissible,
    barrierLabel: barrierLabel,
    motion: motion,
    anchor: anchor,
    dismissAxis: dismissAxis,
    motions: motions,
    style: style,
    // The latest page's child, so updating the page updates the modal.
    builder: (context) =>
        (ModalRoute.settingsOf(context)! as CoilModalPage<T>).child,
  );
}

/// A sheet [CoilModalRoute].
class _CoilModalSheetRoute<T> extends CoilSheetRoute<T>
    implements CoilModalRoute<T> {
  _CoilModalSheetRoute({
    required super.context,
    required super.child,
    super.motion,
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

  /// Starts from where the panel is and how fast it moves, so closing it
  /// mid-entry turns it around with its momentum instead of from rest.
  @override
  Simulation createSimulation({required bool forward}) =>
      (forward ? enter : exit).createSimulation(
        start: animation?.value ?? (forward ? 0 : 1),
        end: forward ? 1 : 0,
        velocity: controller?.velocity ?? 0,
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

/// A floating [CoilModalRoute]: a panel inside the window's margins over the
/// scrim, springing in on Motor like the centered one.
///
/// A drag on [dismissAxis] moves the panel (see [_FloatingPanel]). The
/// route's animation controller is driven by that drag, as Flutter's
/// Cupertino back gesture drives its route's: the controller's value is the
/// panel's presence, `1 - |offset| / extent`, so the scrim fades with the
/// finger through the same animation the exit uses, and the panel's opacity
/// follows it late. While the drag, its spring back or a drag-driven exit
/// runs, the transition doesn't scale or blur the panel: its offset, tilt,
/// slight recede and opacity change.
///
/// It doesn't call the navigator's `didStartUserGesture`: that makes the
/// route's focus scope refuse focus for the length of the drag, which would
/// take focus (and the keyboard) off a search field the moment a swipe
/// starts, and lose where focus returns to.
class _CoilFloatingRoute<T> extends RawDialogRoute<T>
    implements CoilModalRoute<T> {
  _CoilFloatingRoute({
    required this.enter,
    required this.exit,
    required this.settleBack,
    required this.settleAway,
    required this.margin,
    required this.anchor,
    required this.dismissAxis,
    required Color barrierColor,
    required super.barrierDismissible,
    required Widget Function(Widget child) wrapThemes,
    required WidgetBuilder content,
    super.barrierLabel,
    super.settings,
  }) : super(
         barrierColor: barrierColor,
         pageBuilder: (context, _, _) => wrapThemes(
           _FloatingPanel(
             route: ModalRoute.of(context)! as _CoilFloatingRoute<Object?>,
             child: Builder(builder: content),
           ),
         ),
         // The panel does its own transition (see [_FloatingPanel]).
         transitionBuilder: (context, animation, _, child) => child,
       );

  @override
  CoilModalPresentation get presentation => CoilModalPresentation.floating;

  final Motion enter;
  final Motion exit;

  /// The springs of a released drag: back to rest, and away.
  final Motion settleBack;
  final Motion settleAway;

  /// The distance from the window's sides, the top safe area and the
  /// keyboard.
  final double margin;
  final CoilModalAnchor anchor;

  /// The axis a drag dismisses along; null for none.
  final Axis? dismissAxis;

  /// Whether a drag holds the route's animation.
  bool _holding = false;

  /// How fast a drag-driven exit starts, in presence per second.
  double? _exitVelocity;

  /// Starts from where the panel is and how fast it moves, so closing it
  /// mid-entry turns it around with its momentum instead of from rest.
  @override
  Simulation createSimulation({required bool forward}) {
    final velocity = forward
        ? controller?.velocity ?? 0
        : _exitVelocity ?? controller?.velocity ?? 0;
    if (!forward) _exitVelocity = null;
    return (forward ? enter : exit).createSimulation(
      start: animation?.value ?? (forward ? 0 : 1),
      end: forward ? 1 : 0,
      velocity: velocity,
    );
  }

  /// Takes the animation over for a drag. False while the route is leaving.
  bool holdForDrag() {
    if (_holding) return true;
    if (!isActive || controller == null) return false;
    _holding = true;
    controller!.stop();
    return true;
  }

  /// The panel's presence while dragged, 1 at rest to 0 gone.
  void dragTo(double presence) {
    if (_holding) controller!.value = presence.clamp(0.0, 1.0);
  }

  /// Gives the animation back; [exitVelocity] is how fast the coming exit
  /// starts, in presence per second.
  void releaseDrag({double? exitVelocity}) {
    if (!_holding) return;
    _holding = false;
    _exitVelocity = exitVelocity;
  }

  /// Springs the presence back to 1, after a drag that didn't dismiss.
  void resume() {
    final controller = this.controller;
    if (controller == null || !isActive) return;
    unawaited(controller.animateWith(createSimulation(forward: true)));
  }

  @override
  bool didPop(T? result) {
    releaseDrag(exitVelocity: _exitVelocity);
    return super.didPop(result);
  }
}

/// The most a horizontal drag tilts the panel, in radians, at a full extent.
const _maxTilt = 0.06;

/// How much the panel shrinks at a full extent: it recedes as it's thrown.
const _recede = 0.04;

/// Where a released panel would coast, for the decision to throw it away.
/// With `drag: 0.03` a panel coasts `v / -ln(0.03)`, about `v / 3.5`:
/// a flick of 700 px/s from rest lands 200 px out, past half of a phone's
/// panel (about 190 px), a slower one doesn't, and a panel dragged past the
/// middle and flicked back lands short of it again.
const _coast = FrictionMotion(drag: 0.03);

/// The panel's opacity from the route's presence: opaque until it's half
/// way gone, so the scrim leads.
const _lateFade = _LateFade();

class _LateFade extends Animatable<double> {
  const _LateFade();

  @override
  double transform(double t) =>
      1 - _curve.transform(1 - t.clamp(0.0, 1.0));

  /// Solid for the first half of the way, so the page never ghosts through
  /// a panel that's only being moved, then fading in earnest.
  static const _curve = Interval(0.5, 1, curve: Curves.easeIn);
}

/// The floating panel: laid out in the room the window leaves, on a
/// sheet-level surface, with the route's blur-fade and the drag dismissal.
class _FloatingPanel extends StatefulWidget {
  const _FloatingPanel({required this.route, required this.child});

  final _CoilFloatingRoute<Object?> route;
  final Widget child;

  @override
  State<_FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<_FloatingPanel>
    with SingleTickerProviderStateMixin {
  /// How far the panel is moved along the dismiss axis, in fractions of its
  /// extent there (so a spring's velocity is in extents per second).
  late final _slide = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'CoilModalRoute.floating',
  );

  final _panelKey = GlobalKey(debugLabel: 'CoilModalRoute.floating.panel');

  /// A finger holds the panel.
  bool _dragging = false;

  /// A released drag dismissed it: the route's exit runs while the panel
  /// keeps moving the way it was thrown.
  bool _leaving = false;

  /// A drag has touched the panel since it last came to rest: its opacity
  /// follows the drag's curve and it doesn't blur or scale with the route.
  /// Stays through the spring back, so nothing jumps when it arrives.
  bool _touched = false;

  /// The panel's extent along the dismiss axis when the drag started.
  double _extent = 1;

  /// How far the finger has moved the panel, in pixels.
  double _pixels = 0;

  /// Where in the panel the finger took hold, which it tilts around; null
  /// for its center.
  Offset? _grab;

  /// The window's, the panel's own or the system's setting.
  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    widget.route.animation!.addStatusListener(_onPresenceStatus);
  }

  @override
  void dispose() {
    widget.route.animation!.removeStatusListener(_onPresenceStatus);
    _slide.dispose();
    super.dispose();
  }

  /// Back at rest after a drag: the route's own transition takes over.
  void _onPresenceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _touched &&
        !_dragging &&
        !_leaving) {
      setState(() => _touched = false);
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (_leaving || !widget.route.holdForDrag()) return;
    final box = _panelKey.currentContext?.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : null;
    final axis = widget.route.dismissAxis!;
    _extent = math.max(
      1,
      switch (axis) {
            Axis.horizontal => size?.width,
            Axis.vertical => size?.height,
          } ??
          MediaQuery.sizeOf(context).shortestSide,
    );
    // Held where the finger is (for a drag a scrollable handed over, where
    // it began); a panel that can't say gives its center.
    _grab = box is RenderBox && box.hasSize && box.attached
        ? box.globalToLocal(details.globalPosition)
        : null;
    // A panel still springing back is picked up where it is.
    _slide.stop();
    _pixels = _slide.value * _extent;
    setState(() {
      _dragging = true;
      _touched = true;
    });
  }

  void _onDragUpdate(double delta) {
    if (!_dragging) return;
    _pixels += delta;
    final offset = _pixels / _extent;
    _slide.value = offset;
    widget.route.dragTo(1 - offset.abs());
  }

  void _onDragEnd(double velocity, {required bool handedBack}) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    final route = widget.route;
    if (!route.isActive) return;
    // Where the panel would coast to if let go: it is thrown away when that
    // is past half its extent in the direction it travels, so a quick flick
    // from rest, or a slow drag past the middle, goes, and a drag past the
    // middle flicked back toward rest returns.
    final landing = _coast.project(
      from: _pixels,
      velocity: velocity,
      converter: MotionConverter.single,
    );
    final direction = velocity == 0 ? _pixels.sign : velocity.sign;
    final dismiss =
        !handedBack &&
        landing.abs() > _extent / 2 &&
        landing.sign == direction;
    final vetoed = route.popDisposition == RoutePopDisposition.doNotPop;
    final speed = velocity / _extent;
    if (!dismiss) {
      _settleBack(route, speed);
    } else if (vetoed) {
      // Let the PopScope hear it, then spring back.
      unawaited(route.navigator!.maybePop());
      _settleBack(route, speed);
    } else {
      route.releaseDrag(
        // Fading out as fast as the panel moves away.
        exitVelocity: -speed.abs(),
      );
      setState(() => _leaving = true);
      // Reduced motion: no movement, the exit fades.
      if (!_reduceMotion) {
        // It keeps its speed to where it would coast, or clear of the
        // window if that is further.
        final target = math.max(landing.abs(), _distanceOutOfWindow(direction));
        _slide
          ..motion = route.settleAway
          ..animateTo(direction * target / _extent, withVelocity: speed);
      }
      unawaited(route.navigator!.maybePop());
    }
  }

  /// How far the panel has to move from rest along the dismiss axis, toward
  /// [direction] (1 or -1), to be fully outside the window, with room for
  /// its tilt.
  double _distanceOutOfWindow(double direction) {
    final box = _panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return _extent;
    final horizontal = widget.route.dismissAxis == Axis.horizontal;
    final window = MediaQuery.sizeOf(context);
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final restCenter = (horizontal ? center.dx : center.dy) - _pixels;
    final windowExtent = horizontal ? window.width : window.height;
    final tilted = horizontal ? math.sin(_maxTilt) * box.size.height : 0;
    final start = restCenter - _extent / 2;
    final end = restCenter + _extent / 2;
    return (direction > 0 ? windowExtent - start : end) + tilted;
  }

  void _settleBack(_CoilFloatingRoute<Object?> route, double speed) {
    route
      ..releaseDrag()
      ..resume();
    if (_reduceMotion) {
      _slide.value = 0;
    } else {
      _slide
        ..motion = route.settleBack
        ..animateTo(0, withVelocity: speed);
    }
  }

  Widget _scrollDragged(Widget child) {
    final axis = widget.route.dismissAxis;
    if (axis == null) return child;
    return switch (axis) {
      Axis.horizontal => ScrollDragDetector(
        up: ScrollDragMode.none,
        down: ScrollDragMode.none,
        left: ScrollDragMode.boundaryStart,
        right: ScrollDragMode.boundaryStart,
        onHorizontalDragStart: (details, _) => _onDragStart(details),
        onHorizontalDragUpdate: (details, _) =>
            _onDragUpdate(details.primaryDelta ?? 0),
        onHorizontalDragEnd: (details, willScroll) => _onDragEnd(
          details.primaryVelocity ?? 0,
          handedBack: willScroll,
        ),
        onHorizontalDragCancel: () => _onDragEnd(0, handedBack: true),
        child: child,
      ),
      Axis.vertical => ScrollDragDetector(
        up: ScrollDragMode.boundaryStart,
        down: ScrollDragMode.boundaryStart,
        left: ScrollDragMode.none,
        right: ScrollDragMode.none,
        onVerticalDragStart: (details, _) => _onDragStart(details),
        onVerticalDragUpdate: (details, _) =>
            _onDragUpdate(details.primaryDelta ?? 0),
        onVerticalDragEnd: (details, willScroll) => _onDragEnd(
          details.primaryVelocity ?? 0,
          handedBack: willScroll,
        ),
        onVerticalDragCancel: () => _onDragEnd(0, handedBack: true),
        child: child,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final media = MediaQuery.of(context);
    final radius = BorderRadius.circular(
      CoilSheetRoute.cornerRadiusOf(context),
    );
    final top = route.anchor == CoilModalAnchor.top;
    final margin = route.margin;
    // The room the window leaves: clear of the safe areas, and of the
    // keyboard, which covers the home indicator.
    final room = EdgeInsets.fromLTRB(
      media.padding.left + margin,
      media.padding.top + margin,
      media.padding.right + margin,
      [
            media.viewInsets.bottom,
            media.viewPadding.bottom,
            media.padding.bottom,
          ].reduce(math.max) +
          margin,
    );
    final axis = route.dismissAxis;

    // The panel cleared the insets, so what it holds has none left.
    final content = MediaQuery(
      data: media.copyWith(
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: widget.child,
    );
    final panel = KeyedSubtree(
      key: _panelKey,
      child: _scrollDragged(
        CoilSurface(
          offset: CoilSurface.popoverOffset,
          borderRadius: radius,
          child: ClipRSuperellipse(borderRadius: radius, child: content),
        ),
      ),
    );
    return Padding(
      padding: room,
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CoilSheetRoute.maxWidth),
          child: SizedBox(
            width: double.infinity,
            child: ListenableBuilder(
              listenable: _slide,
              child: panel,
              builder: (context, child) {
                // A drag moves the panel, tilts it around the finger and
                // lets it recede a little, and fades it late, after the
                // scrim has led. Otherwise it's the route's blur-fade.
                final driven = _touched || _dragging || _leaving;
                final offset = _slide.value;
                final moving = driven && !_reduceMotion;
                final depth = offset.abs().clamp(0.0, 1.0);
                final tilt = moving && axis == Axis.horizontal
                    ? offset * _maxTilt
                    : 0.0;
                final scale = moving ? 1 - _recede * depth : 1.0;
                final tilted = tilt != 0 || scale != 1;
                return CoilBlurFade(
                  presence: driven
                      ? route.animation!.drive(_lateFade)
                      : route.animation!,
                  scale: driven ? 1 : 0.97,
                  blur: driven ? 0 : CoilBlurFade.defaultBlur,
                  child: FractionalTranslation(
                    translation: switch (axis) {
                      null => Offset.zero,
                      Axis.horizontal => Offset(offset, 0),
                      Axis.vertical => Offset(0, offset),
                    },
                    // Resampled as one image, like the blur-fade's own scale.
                    child: Transform(
                      transform: Matrix4.rotationZ(tilt)
                        ..scaleByDouble(scale, scale, 1, 1),
                      origin: _grab,
                      alignment: _grab == null ? Alignment.center : null,
                      filterQuality: tilted ? FilterQuality.medium : null,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
