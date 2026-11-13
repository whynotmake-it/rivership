import 'dart:math' as math;

import 'package:coil/src/foundation/typography.dart';
import 'package:coil/src/primitives/drawn_glyph.dart';
import 'package:coil/src/primitives/focus_ring.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A button that opens and closes a region under it: a label and a
/// chevron that turns a quarter toward the region when it opens.
///
/// The label turns semibold while [expanded]. The chevron, and any
/// [leading] glyph, are styled by an [IconTheme] in the [foreground]
/// color, at emphasis weight while expanded, hovered or focused.
///
/// It takes resolved look values, so a component maps its own style and
/// track motions onto it. [fill] and [foreground] are resolved with
/// [WidgetState.hovered], [WidgetState.focused], [WidgetState.pressed] and
/// [WidgetState.disabled].
///
/// Screen readers hear a button with an expanded state that controls
/// [controlsNodes].
class CoilDisclosureTrigger extends StatelessWidget {
  /// Creates a disclosure trigger.
  const CoilDisclosureTrigger({
    required this.label,
    required this.expanded,
    required this.onPressed,
    required this.fill,
    required this.foreground,
    required this.textStyle,
    required this.radius,
    required this.minHeight,
    required this.padding,
    required this.gap,
    required this.iconSize,
    required this.chevronMotion,
    required this.fillMotion,
    required this.fillExitMotion,
    required this.labelMotion,
    required this.weightMotion,
    super.key,
    this.leading,
    this.indicator,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.minHitTarget = 0,
    this.disabledOpacity = 1,
    this.focusRingOffset,
    this.mainAxisSize = MainAxisSize.max,
    this.controlsNodes,
  });

  /// The trigger's text, one line, ellipsized.
  final Widget label;

  /// Whether the region is open.
  final bool expanded;

  /// Called when the trigger is pressed. Null disables it.
  final VoidCallback? onPressed;

  /// The trigger's background.
  final WidgetStateProperty<Color?> fill;

  /// The label, glyph and chevron color.
  final WidgetStateProperty<Color?> foreground;

  /// The label's style at rest. Its color comes from [foreground].
  final TextStyle textStyle;

  /// The corner radius of the fill and the focus ring.
  final double radius;

  /// The smallest height of the row.
  final double minHeight;

  /// The space around the row's content.
  final EdgeInsetsGeometry padding;

  /// The space between the leading glyph, the label and the chevron.
  final double gap;

  /// The size of the glyphs before text scaling.
  final double iconSize;

  /// The chevron's quarter turn.
  final Motion chevronMotion;

  /// The fill showing.
  final Motion fillMotion;

  /// The fill clearing.
  final Motion fillExitMotion;

  /// The label color.
  final Motion labelMotion;

  /// The label weight.
  final Motion weightMotion;

  /// An optional glyph before the label.
  final Widget? leading;

  /// Replaces the chevron.
  final Widget? indicator;

  /// The trigger's focus node.
  final FocusNode? focusNode;

  /// Whether the trigger takes focus when first built.
  final bool autofocus;

  /// Observes, and can force, the trigger's states.
  final WidgetStatesController? statesController;

  /// The smallest square the hit area may be.
  final double minHitTarget;

  /// The trigger's opacity while disabled.
  final double disabledOpacity;

  /// How far outside the trigger its focus ring sits. Null draws no ring,
  /// for a list that draws one shared ring.
  final double? focusRingOffset;

  /// Whether the row fills the width or hugs its content.
  final MainAxisSize mainAxisSize;

  /// The semantics identifiers of the region the trigger opens.
  final Set<String>? controlsNodes;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      expanded: expanded,
      controlsNodes: controlsNodes,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        statesController: statesController,
        minHitTarget: minHitTarget,
        builder: (context, states, _) {
          final fill = this.fill.resolve(states)!;
          final color = foreground.resolve(states)!;
          final lit =
              expanded ||
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused);
          Widget trigger = MotionBuilder<Color>(
            value: fill,
            motion: fill.a > 0 ? fillMotion : fillExitMotion,
            converter: MotionConverter.colorRgb,
            debugLabel: 'CoilDisclosureTrigger.fill',
            builder: (context, fill, child) => DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
              ),
              child: child,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: padding,
                child: MotionBuilder<Color>(
                  value: color,
                  motion: labelMotion,
                  converter: MotionConverter.colorRgb,
                  debugLabel: 'CoilDisclosureTrigger.label',
                  builder: (context, color, _) => IconTheme(
                    data: IconThemeData(
                      size: iconSize,
                      applyTextScaling: true,
                      color: color,
                      weight: lit
                          ? CoilIconWeight.emphasis
                          : CoilIconWeight.rest,
                    ),
                    child: Row(
                      mainAxisSize: mainAxisSize,
                      spacing: gap,
                      children: [
                        ?leading,
                        Flexible(
                          fit: mainAxisSize == MainAxisSize.max
                              ? FlexFit.tight
                              : FlexFit.loose,
                          child: _Label(
                            expanded: expanded,
                            style: textStyle.copyWith(color: color),
                            motion: weightMotion,
                            child: label,
                          ),
                        ),
                        SingleMotionBuilder(
                          value: expanded ? (rtl ? -0.25 : 0.25) : 0,
                          motion: chevronMotion,
                          debugLabel: 'CoilDisclosureTrigger.chevron',
                          builder: (context, turns, child) => Transform.rotate(
                            angle: turns * 2 * math.pi,
                            child: child,
                          ),
                          child:
                              indicator ??
                              const CoilDrawnGlyph(CoilGlyph.chevronEnd),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          if (focusRingOffset case final offset?) {
            trigger = CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: borderRadius,
              offset: offset,
              child: trigger,
            );
          }
          return Opacity(
            opacity: onPressed == null ? disabledOpacity : 1,
            child: trigger,
          );
        },
      ),
    );
  }
}

/// The label, its weight springing between normal and semibold. The
/// weights pair `wght` with `opsz`, so the width barely changes.
class _Label extends StatelessWidget {
  const _Label({
    required this.expanded,
    required this.style,
    required this.motion,
    required this.child,
  });

  final bool expanded;
  final TextStyle style;
  final Motion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: expanded ? 1 : 0,
    motion: motion,
    debugLabel: 'CoilDisclosureTrigger.weight',
    builder: (context, t, child) => DefaultTextStyle(
      style: style.copyWith(
        fontVariations: CoilWeight.lerp(
          CoilWeight.normal,
          CoilWeight.semibold,
          t,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      child: child!,
    ),
    child: child,
  );
}
