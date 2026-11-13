import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/breadcrumb/breadcrumb_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A breadcrumb's resolved track motions.
@immutable
class CrumbMotions {
  /// Creates the motions.
  const CrumbMotions({
    required this.pressIn,
    required this.pressOut,
    required this.label,
  });

  /// The press fill as a finger lands.
  final Motion pressIn;

  /// The press fill as the finger lifts.
  final Motion pressOut;

  /// The label color.
  final Motion label;
}

/// A link crumb (or "…"): the label and its trailing separator in one
/// pressable box, which the trail's highlight glides between.
class CrumbLink extends StatelessWidget {
  /// Creates a link crumb.
  const CrumbLink({
    required this.index,
    required this.label,
    required this.onPressed,
    required this.separator,
    required this.metrics,
    required this.motions,
    required this.style,
    super.key,
    this.leading,
    this.semanticLabel,
    this.link = true,
    this.focusNode,
  });

  /// The crumb's index in the trail's hover region.
  final int index;

  /// The visible label.
  final String label;

  /// Replaces [label] for screen readers.
  final String? semanticLabel;

  /// A glyph before the label.
  final Widget? leading;

  /// Follows the link. Null disables it.
  final VoidCallback? onPressed;

  /// The glyph after the label.
  final Widget separator;

  /// The crumb sizes.
  final CoilMetrics metrics;

  /// The resolved motions.
  final CrumbMotions motions;

  /// The resolved look.
  final CoilBreadcrumbStyle style;

  /// A link, or a button ("…").
  final bool link;

  /// The focus node, for a crumb its owner focuses.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(style.radius!);
    return Semantics(
      link: link,
      button: !link,
      label: semanticLabel,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final pressed = states.contains(WidgetState.pressed);
          final hovered = states.contains(WidgetState.hovered);
          final emphasized =
              pressed || hovered || states.contains(WidgetState.focused);
          // A finger gets a fill while it presses; a hovering pointer
          // already shows the highlight.
          final fill = pressed && !hovered
              ? style.pressFill!
              : style.pressFill!.withValues(alpha: 0);
          return Opacity(
            opacity: enabled ? 1 : metrics.disabledOpacity,
            child: CoilHoverItem(
              index: index,
              enabled: enabled,
              child: CoilFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                offset: style.focusRingOffset!,
                child: MotionBuilder<Color>(
                  value: fill,
                  converter: MotionConverter.colorRgb,
                  motion: pressed ? motions.pressIn : motions.pressOut,
                  debugLabel: 'CoilBreadcrumb.press',
                  builder: (context, fill, child) => DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: RoundedSuperellipseBorder(borderRadius: radius),
                    ),
                    child: child,
                  ),
                  child: MotionBuilder<Color>(
                    value: style.label!.resolve(states)!,
                    converter: MotionConverter.colorRgb,
                    motion: motions.label,
                    debugLabel: 'CoilBreadcrumb.label',
                    builder: (context, color, _) => CrumbContent(
                      label: label,
                      labelInSemantics: semanticLabel == null,
                      leading: leading,
                      color: color,
                      emphasized: emphasized,
                      separator: separator,
                      style: style,
                      metrics: metrics,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The current page: foreground text, not a link, marked selected.
class CrumbPage extends StatelessWidget {
  /// Creates the current page crumb.
  const CrumbPage({
    required this.label,
    required this.leading,
    required this.metrics,
    required this.style,
    super.key,
  });

  /// The page's name.
  final String label;

  /// A glyph before the label.
  final Widget? leading;

  /// The crumb sizes.
  final CoilMetrics metrics;

  /// The resolved look.
  final CoilBreadcrumbStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: true,
    child: CrumbContent(
      label: label,
      leading: leading,
      color: style.label!.resolve({WidgetState.selected})!,
      emphasized: false,
      separator: null,
      style: style,
      metrics: metrics,
    ),
  );
}

/// The leading glyph, label and separator, at least the crumb height and
/// centered in it. The label truncates when the trail gives it less than
/// its width.
class CrumbContent extends StatelessWidget {
  /// Creates the content.
  const CrumbContent({
    required this.label,
    required this.leading,
    required this.color,
    required this.emphasized,
    required this.separator,
    required this.style,
    required this.metrics,
    super.key,
    this.labelInSemantics = true,
  });

  /// The label.
  final String label;

  /// Whether screen readers read [label].
  final bool labelInSemantics;

  /// A glyph before the label.
  final Widget? leading;

  /// The label and leading color.
  final Color color;

  /// Whether the leading glyph draws at its emphasis weight.
  final bool emphasized;

  /// The glyph after the label, or null for the page.
  final Widget? separator;

  /// The resolved look.
  final CoilBreadcrumbStyle style;

  /// The crumb sizes.
  final CoilMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final padX = style.paddingX!;
    final gap = style.separatorGap!;
    final separator = this.separator;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.minHeight!),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: padX,
          end: separator == null ? padX : gap,
        ),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading case final leading?) ...[
                IconTheme(
                  data: IconThemeData(
                    size: metrics.iconSize,
                    color: color,
                    weight: emphasized
                        ? CoilIconWeight.emphasis
                        : CoilIconWeight.rest,
                    applyTextScaling: true,
                  ),
                  child: leading,
                ),
                SizedBox(width: metrics.gap),
              ],
              Flexible(
                child: ExcludeSemantics(
                  excluding: !labelInSemantics,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    // A truncated label is as wide as its ink, so the
                    // separator follows it closely.
                    textWidthBasis: TextWidthBasis.longestLine,
                    style: style.textStyle!.copyWith(color: color),
                  ),
                ),
              ),
              if (separator != null) ...[
                SizedBox(width: gap),
                ExcludeSemantics(
                  child: IconTheme(
                    data: IconThemeData(
                      size: style.separatorSize,
                      color: style.separatorColor,
                      applyTextScaling: true,
                    ),
                    child: separator,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
