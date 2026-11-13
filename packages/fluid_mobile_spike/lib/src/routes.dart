// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:math' as math;

import 'package:fluid_mobile_spike/src/adaptive.dart';
import 'package:fluid_mobile_spike/src/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Which side of its anchor a popover landed on after collision handling.
enum FluidPopoverSide {
  /// Below the anchor (the requested side).
  bottom,

  /// Above the anchor, flipped for lack of room below.
  top,
}

/// An anchored popover: enters on the theme's popover spring (opacity, a
/// 4px slide away from the anchor and scaleY 0.96 → 1 from the anchored
/// edge) and exits on its tween (`FluidMotionThemeData.popover` /
/// `popoverExit`).
///
/// What you see is a [PhaseTrackBuilder] with two phases, `closed` and
/// `open`. It mounts in `open`, starting from the closed values, and goes to
/// `closed` when the route is popped. Every track springs in and tweens out.
///
/// The route stays a [PopupRoute] for what routes give for free (a focus
/// scope, the dismissible barrier, Escape/back handling, `Navigator.pop`
/// returning the result). Its own animation is only its lifetime: a
/// [TransitionRoute] is removed once its internal controller finishes, so
/// [reverseTransitionDuration] is set to the exit tween's duration. Motor
/// has no hook to tell a route "the exit has settled".
class FluidPopoverRoute<T> extends PopupRoute<T> {
  /// Creates a popover anchored to [anchor] (in the navigator's coordinates).
  FluidPopoverRoute({
    required this.anchor,
    required this.builder,
    required this.contentHeight,
    this.minWidth = 0,
    this.maxHeight = 300,
    this.sideOffset = 6,
    this.edgePadding = 8,
    this.capturedThemes,
    this.exitDuration = const Duration(milliseconds: 60),
    super.settings,
  });

  /// How long the route stays mounted after it is popped: the theme's
  /// popover exit duration, read when the popover was opened.
  final Duration exitDuration;

  /// The trigger's rect.
  final Rect anchor;

  /// The popup's contents.
  final WidgetBuilder builder;

  /// The natural height of the contents, used to pick a side before layout.
  final double contentHeight;

  /// Minimum popup width (the trigger's width).
  final double minWidth;

  /// Maximum popup height.
  final double maxHeight;

  /// Gap between the anchor and the popup.
  final double sideOffset;

  /// Distance kept from the window edges.
  final double edgePadding;

  /// Inherited widgets carried over from the trigger's context.
  final CapturedThemes? capturedThemes;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  final _popped = ValueNotifier(false);

  @override
  bool didPop(T? result) {
    _popped.value = true;
    return super.didPop(result);
  }

  @override
  void dispose() {
    _popped.dispose();
    super.dispose();
  }

  // In: the phase builder springs on its own; the route is "open" at once.
  @override
  Duration get transitionDuration => Duration.zero;

  // Out: the route stays mounted while the exit tween plays.
  @override
  Duration get reverseTransitionDuration => exitDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final window = Offset.zero & media.size;
    final safe = media.padding;
    final spaceBelow =
        window.bottom - safe.bottom - edgePadding - anchor.bottom - sideOffset;
    final spaceAbove = anchor.top - sideOffset - edgePadding - safe.top;
    final wanted = math.min(contentHeight, maxHeight);
    final side = spaceBelow >= wanted || spaceBelow >= spaceAbove
        ? FluidPopoverSide.bottom
        : FluidPopoverSide.top;
    final available = side == FluidPopoverSide.bottom ? spaceBelow : spaceAbove;
    final height = math.max(0, math.min(maxHeight, available)).toDouble();

    // The opener's themes wrap the motion too, so it reads the opener's
    // motion tokens.
    Widget wrap(Widget child) => capturedThemes?.wrap(child) ?? child;

    return CustomSingleChildLayout(
      delegate: _PopoverLayout(
        anchor: anchor,
        side: side,
        sideOffset: sideOffset,
        edgePadding: edgePadding,
        minWidth: minWidth,
        maxHeight: height,
      ),
      child: wrap(
        _PopoverMotion(
          popped: _popped,
          side: side,
          child: Builder(builder: builder),
        ),
      ),
    );
  }
}

enum _PopoverPhase { closed, open }

/// The popover's enter and exit, as named phases. `popupMotionClass` and the
/// select's `initial`/`animate`/`exit` on the web: opacity 0 → 1, a 4px
/// slide away from the anchor, scaleY 0.96 → 1 from the anchored edge.
class _PopoverMotion extends StatefulWidget {
  const _PopoverMotion({
    required this.popped,
    required this.side,
    required this.child,
  });

  /// Flips to true when the route is popped: the one lifecycle event the
  /// popover needs from its route.
  final ValueListenable<bool> popped;
  final FluidPopoverSide side;
  final Widget child;

  @override
  State<_PopoverMotion> createState() => _PopoverMotionState();
}

class _PopoverMotionState extends State<_PopoverMotion> {
  final _opacity = Track<double>(
    MotionConverter.single,
    debugLabel: 'Popover opacity',
  );
  final _slide = Track<double>(
    MotionConverter.single,
    debugLabel: 'Popover slide',
  );
  final _scaleY = Track<double>(
    MotionConverter.single,
    debugLabel: 'Popover scaleY',
  );

  @override
  Widget build(BuildContext context) {
    final motion = FluidTheme.motionOf(context);
    final enter = motion.popover;
    final exit = motion.popoverExit;
    final bottom = widget.side == FluidPopoverSide.bottom;
    return MotorInspectionScope(
      group: 'FluidPopover',
      child: ValueListenableBuilder(
        valueListenable: widget.popped,
        child: widget.child,
        builder: (context, popped, child) => PhaseTrackBuilder<_PopoverPhase>(
          debugLabel: 'Popover',
          // Mounts in the open phase, starting from the closed values, so it
          // springs open on its first frame.
          currentPhase: popped ? _PopoverPhase.closed : _PopoverPhase.open,
          timeline: TrackPhaseTimeline(
            {
              _PopoverPhase.closed: [
                _opacity([TrackStep.to(0, motion: exit)]),
                _slide([TrackStep.to(1, motion: exit)]),
                _scaleY([TrackStep.to(0.96, motion: exit)]),
              ],
              _PopoverPhase.open: [
                _opacity([TrackStep.to(1, motion: enter)]),
                _slide([TrackStep.to(0, motion: enter)]),
                _scaleY([TrackStep.to(1, motion: enter)]),
              ],
            },
            initialValues: [
              _opacity.value(0),
              _slide.value(1),
              _scaleY.value(0.96),
            ],
          ),
          child: child,
          builder: (context, value, phase, child) => Opacity(
            opacity: value(_opacity).clamp(0.0, 1.0),
            child: Transform.translate(
              // --popup-enter-y: -4px below the anchor, +4px above it.
              offset: Offset(0, (bottom ? -4.0 : 4.0) * value(_slide)),
              child: Transform(
                alignment: bottom
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1, value(_scaleY), 1),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({
    required this.anchor,
    required this.side,
    required this.sideOffset,
    required this.edgePadding,
    required this.minWidth,
    required this.maxHeight,
  });

  final Rect anchor;
  final FluidPopoverSide side;
  final double sideOffset;
  final double edgePadding;
  final double minWidth;
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0, constraints.maxWidth - edgePadding * 2);
    return BoxConstraints(
      minWidth: math.min(minWidth, maxWidth).toDouble(),
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // align="start", shifted back inside the window if it would overflow.
    final x = anchor.left
        .clamp(
          edgePadding,
          math.max(edgePadding, size.width - edgePadding - childSize.width),
        )
        .toDouble();
    final y = side == FluidPopoverSide.bottom
        ? anchor.bottom + sideOffset
        : anchor.top - sideOffset - childSize.height;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      anchor != old.anchor ||
      side != old.side ||
      minWidth != old.minWidth ||
      maxHeight != old.maxHeight;
}

/// The touch presentation: a `stupid_simple_sheet` route (itself driven by
/// Motor) that enters on [motion] and exits on [exitMotion]. The select
/// passes the theme's `sheet` / `sheetExit` tokens (the web's mobile-drawer
/// tier).
class FluidSheetRoute<T> extends StupidSimpleSheetRoute<T> {
  /// Creates a sheet route.
  FluidSheetRoute({
    required Widget child,
    required super.motion,
    required this.exitMotion,
    CapturedThemes? capturedThemes,
    super.settings,
  }) : super(
         child: capturedThemes?.wrap(child) ?? child,
         barrierColor: const Color(0x66000000), // bg-black/40
       );

  /// The closing tween.
  final Motion exitMotion;

  @override
  Duration get reverseTransitionDuration =>
      exitMotion.duration ?? const Duration(milliseconds: 120);

  @override
  Simulation? createSimulation({required bool forward}) {
    // Opening (and snapping back after a drag) stays on the spring.
    final spring = super.createSimulation(forward: forward);
    if (forward) return spring;
    return exitMotion.createSimulation(
      start: controller?.value ?? 1,
      end: 0,
    );
  }
}

/// The floating panel a [FluidSheetRoute] shows: inset from the screen
/// edges, the popup shell's surface and shadow at touch radius, a grabber,
/// an optional title, then [child].
class FluidSheetPanel extends StatelessWidget {
  /// Creates a panel.
  const FluidSheetPanel({required this.child, this.title, super.key});

  /// An optional heading, in the title role.
  final Widget? title;

  /// The panel contents (usually a list).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    const metrics = FluidMetrics.touch;
    final media = MediaQuery.of(context);
    // Sheets sit 8px inside the screen edges (and the home indicator), with
    // the popup shell's radius, so they read as the same object as the
    // desktop popover rather than a platform sheet.
    const margin = 8.0;
    final radius = BorderRadius.circular(metrics.itemRadius + margin);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        margin,
        media.padding.top + 48,
        margin,
        math.max(margin, media.padding.bottom),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface(3),
          borderRadius: radius,
          boxShadow: colors.shadow(3),
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: colors.insetRing(3),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.foreground.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (title case final title?)
                  Padding(
                    // Lined up with the rows' labels: 2 + 6 + 10 = 18.
                    padding: const EdgeInsets.fromLTRB(
                      margin + 10,
                      4,
                      margin + 10,
                      4,
                    ),
                    child: DefaultTextStyle(
                      style: metrics.caption.style(
                        weight: FontWeight.w600,
                        color: colors.mutedForeground,
                      ),
                      child: title,
                    ),
                  ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(margin - 6),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
