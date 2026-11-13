import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/accordion/accordion_item.dart';
import 'package:coil/src/components/accordion/accordion_style.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One section: the trigger over its collapsible panel, with the open tint
/// behind both in the group variant.
class AccordionSection<T> extends StatelessWidget {
  /// Creates a section.
  const AccordionSection({
    required this.index,
    required this.item,
    required this.open,
    required this.group,
    required this.indicator,
    required this.focusNode,
    required this.statesController,
    required this.onPressed,
    required this.metrics,
    required this.motion,
    required this.motions,
    required this.style,
    super.key,
  });

  /// The item's position, for the group's hover highlight.
  final int index;

  /// The item.
  final CoilAccordionItem<T> item;

  /// Whether the panel is open.
  final bool open;

  /// Whether the accordion is the group variant.
  final bool group;

  /// Replaces the chevron.
  final Widget? indicator;

  /// The trigger's focus node.
  final FocusNode focusNode;

  /// The trigger's states.
  final WidgetStatesController statesController;

  /// Toggles the item. Null disables it.
  final VoidCallback? onPressed;

  /// The accordion's metrics.
  final CoilMetrics metrics;

  /// The accordion's motion tokens.
  final CoilMotion motion;

  /// The accordion's per-track motions.
  final Map<CoilAccordionTrack<Object>, Motion>? motions;

  /// The accordion's resolved style.
  final CoilAccordionStyle style;

  @override
  Widget build(BuildContext context) {
    Motion track(
      CoilAccordionTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: motions,
      token: token,
      spatial: spatial,
    );
    // Unique per item, so the trigger can point screen readers at its panel.
    final panelId = 'CoilAccordion.panel.${identityHashCode(focusNode)}';

    Widget trigger = CoilDisclosureTrigger(
      label: Text(item.label),
      leading: item.leading,
      indicator: indicator,
      expanded: open,
      onPressed: onPressed,
      focusNode: focusNode,
      statesController: statesController,
      controlsNodes: {panelId},
      fill: style.triggerFill!,
      foreground: open ? style.expandedLabel! : style.label!,
      textStyle: style.textStyle!,
      radius: style.radius!,
      minHeight: metrics.controlHeight,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.controlPaddingX,
        vertical: metrics.controlPaddingY(metrics.body),
      ),
      gap: metrics.gap,
      iconSize: metrics.iconSize,
      minHitTarget: metrics.minHitTarget,
      // Touch rows rest at full foreground, so disabled ones fade further.
      disabledOpacity: metrics.disabledRowOpacity,
      // The group draws one shared ring instead.
      focusRingOffset: group ? null : style.focusRingOffset,
      chevronMotion: track(
        CoilAccordionTrack.chevron,
        open ? motion.quick : motion.quickExit,
      ),
      fillMotion: track(CoilAccordionTrack.fill, motion.fade, spatial: false),
      fillExitMotion: track(
        CoilAccordionTrack.fill,
        motion.fadeExit,
        spatial: false,
      ),
      labelMotion: track(
        CoilAccordionTrack.label,
        motion.fade,
        spatial: false,
      ),
      weightMotion: track(
        CoilAccordionTrack.weight,
        motion.fade,
        spatial: false,
      ),
    );
    if (group) {
      trigger = CoilHoverItem(
        index: index,
        enabled: onPressed != null,
        child: trigger,
      );
    }
    final section = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        trigger,
        CoilCollapsible(
          expanded: open,
          heightMotion: track(
            CoilAccordionTrack.height,
            open ? motion.standard : motion.standardExit,
          ),
          opacityMotion: track(
            CoilAccordionTrack.opacity,
            open ? motion.fade : motion.fadeExit,
            spatial: false,
          ),
          debugLabel: 'CoilAccordion.panel',
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            role: SemanticsRole.region,
            label: item.label,
            identifier: panelId,
            child: Padding(
              padding: style.panelPadding!,
              child: DefaultTextStyle(
                style: style.panelTextStyle!,
                child: item.panel,
              ),
            ),
          ),
        ),
      ],
    );
    if (!group) return section;
    final tint = style.openTint!;
    return MotionBuilder<Color>(
      value: open ? tint : tint.withValues(alpha: 0),
      motion: track(
        CoilAccordionTrack.tint,
        open ? motion.fade : motion.fadeExit,
        spatial: false,
      ),
      converter: MotionConverter.colorRgb,
      debugLabel: 'CoilAccordion.tint',
      builder: (context, color, child) => DecoratedBox(
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(style.radius!),
          ),
        ),
        child: child,
      ),
      child: section,
    );
  }
}
