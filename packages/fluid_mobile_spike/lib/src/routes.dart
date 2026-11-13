import 'dart:math' as math;

import 'package:fluid_mobile_spike/src/adaptive.dart';
import 'package:fluid_mobile_spike/src/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// Which side of its anchor a popover landed on after collision handling.
enum FluidPopoverSide {
  /// Below the anchor (the requested side).
  bottom,

  /// Above the anchor, flipped for lack of room below.
  top,
}

/// An anchored popover: enters on [FluidMotion.fast] (opacity, a 4px slide
/// away from the anchor and scaleY 0.96 → 1 from the anchored edge) and
/// exits on [FluidMotion.fastExit].
///
/// The route's animation itself is driven by Motor: [createSimulation]
/// returns the spring going in and the tween going out.
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
    super.settings,
  });

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

  @override
  Duration get transitionDuration => FluidMotion.fast.duration;

  @override
  Duration get reverseTransitionDuration => FluidMotion.fastExit.duration;

  @override
  Simulation? createSimulation({required bool forward}) {
    final start = controller?.value ?? (forward ? 0 : 1);
    return forward
        ? FluidMotion.fast.createSimulation(start: start)
        : FluidMotion.fastExit.createSimulation(start: start, end: 0);
  }

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

    Widget child = Builder(builder: builder);
    child = capturedThemes?.wrap(child) ?? child;

    return CustomSingleChildLayout(
      delegate: _PopoverLayout(
        anchor: anchor,
        side: side,
        sideOffset: sideOffset,
        edgePadding: edgePadding,
        minWidth: minWidth,
        maxHeight: height,
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value.clamp(0.0, 1.0);
          final direction = side == FluidPopoverSide.bottom ? -1.0 : 1.0;
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, direction * 4 * (1 - t)),
              child: Transform(
                alignment: side == FluidPopoverSide.bottom
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1, 0.96 + 0.04 * t, 1),
                child: child,
              ),
            ),
          );
        },
        child: child,
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

/// The touch presentation: a `stupid_simple_sheet` route that enters on
/// [FluidMotion.moderate] (the web's mobile-drawer tier) and exits on its
/// tween, [FluidMotion.moderateExit].
class FluidSheetRoute<T> extends StupidSimpleSheetRoute<T> {
  /// Creates a sheet route.
  FluidSheetRoute({required super.child, super.settings})
    : super(
        motion: FluidMotion.moderate,
        barrierColor: const Color(0x66000000), // bg-black/40
      );

  @override
  Duration get reverseTransitionDuration => FluidMotion.moderateExit.duration;

  @override
  Simulation? createSimulation({required bool forward}) {
    // Opening (and snapping back after a drag) stays on the spring.
    final spring = super.createSimulation(forward: forward);
    if (forward) return spring;
    return FluidMotion.moderateExit.createSimulation(
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
                    padding: const EdgeInsets.fromLTRB(
                      margin + 12,
                      4,
                      margin + 12,
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
