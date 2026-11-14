import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/src/components/sidebar/sidebar_scope.dart';
import 'package:coil/src/components/sidebar/sidebar_style.dart';
import 'package:coil/src/components/sidebar/sidebar_text.dart';
import 'package:coil/tooltip.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The sidebar's row height per tier and size: 32 / 28 on pointer, 44 /
/// 36 on touch. Heights are minimums.
double coilSidebarRowHeight(CoilMetrics metrics) =>
    switch ((metrics.tier, metrics.size)) {
      (CoilTier.pointer, CoilSize.regular) => 32,
      (CoilTier.pointer, CoilSize.compact) => 28,
      (CoilTier.touch, CoilSize.regular) => 44,
      (CoilTier.touch, CoilSize.compact) => 36,
    };

/// The space between a trailing 24 box and the row's end, so every action,
/// badge and chevron in the sidebar shares one axis.
const double _trailingInset = 6;

CoilSidebarStyle _styleOf(BuildContext context, CoilSidebarStyle? style) =>
    CoilSidebarStyle.fallback(
      CoilTheme.of(context),
      CoilTheme.metricsOf(context),
    ).merge(CoilTheme.styleOf<CoilSidebarStyle>(context)).merge(style);

/// The sidebar's panel: a [header], scrolling [children] and a [footer].
///
/// The header and footer stay put while the children scroll, with edge
/// fades. Stack the header's or footer's parts in a `Column` (each on its
/// own row, actions as menu rows) or a [CoilSidebarBar] (the primary part
/// with icon actions beside it).
class CoilSidebar extends StatelessWidget {
  /// Creates a sidebar panel.
  const CoilSidebar({
    required this.children,
    super.key,
    this.header,
    this.footer,
    this.semanticLabel,
    this.style,
  });

  /// Above the scrolling content, such as a workspace switcher.
  final Widget? header;

  /// The groups, usually [CoilSidebarGroup]s.
  final List<Widget> children;

  /// Below the scrolling content, such as callouts and the signed-in user.
  final Widget? footer;

  /// Names the sidebar for screen readers and makes it a navigation
  /// landmark. Each sidebar on screen needs its own name.
  final String? semanticLabel;

  /// Overrides the theme's sidebar style.
  final CoilSidebarStyle? style;

  @override
  Widget build(BuildContext context) {
    final look = _styleOf(context, style);
    final scope = CoilSidebarScope.maybeOf(context);
    final left = scope?.physicalLeft ?? true;
    final padding = EdgeInsets.all(look.padding!);
    return Semantics(
      role: semanticLabel == null ? null : SemanticsRole.navigation,
      label: semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: SafeArea(
        left: left,
        right: !left,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header case final header?)
              Padding(padding: padding, child: header),
            Expanded(
              child: CoilScrollArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            if (footer case final footer?)
              Padding(padding: padding, child: footer),
          ],
        ),
      ),
    );
  }
}

/// A header or footer row: the [primary] part, such as a workspace switcher
/// or the user's menu, with [actions] beside it on the sidebar's trailing
/// action axis.
class CoilSidebarBar extends StatelessWidget {
  /// Creates a bar.
  const CoilSidebarBar({
    required this.primary,
    super.key,
    this.actions = const [],
    this.style,
  });

  /// The main part; it takes the width the actions leave.
  final Widget primary;

  /// One to three [CoilSidebarAction]s.
  final List<Widget> actions;

  /// Overrides the theme's sidebar style.
  final CoilSidebarStyle? style;

  @override
  Widget build(BuildContext context) {
    final look = _styleOf(context, style);
    if (actions.isEmpty) return primary;
    return Row(
      spacing: look.actionGap!,
      children: [
        Expanded(child: primary),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: _trailingInset),
          child: CoilTooltipGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: look.actionGap!,
              children: actions,
            ),
          ),
        ),
      ],
    );
  }
}

/// The sidebar's icon button: a 24 square with a 16 icon, used in bars,
/// group labels and rows so every action lines up on one rhythm.
///
/// On a touch screen its hit area grows to 44. [tooltip] names it on hover,
/// with [shortcut]'s keys;
/// leave it null for a button that opens a menu.
class CoilSidebarAction extends StatelessWidget {
  /// Creates an action.
  const CoilSidebarAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.shortcut,
    this.focusNode,
    this.style,
  });

  /// The icon, styled by [IconTheme].
  final Widget icon;

  /// Names the action for screen readers.
  final String semanticLabel;

  /// Called on tap, Enter or Space. Null disables the action.
  final VoidCallback? onPressed;

  /// The tooltip, usually a [Text].
  final Widget? tooltip;

  /// A shortcut the tooltip shows after [tooltip], usually a `CoilKbd`,
  /// such as `CoilKbd.activator(activator)`.
  final Widget? shortcut;

  /// The action's focus node.
  final FocusNode? focusNode;

  /// Overrides the theme's sidebar style.
  final CoilSidebarStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context);
    final look = _styleOf(context, style);
    final radius = BorderRadius.circular(
      theme.shape.radii(metrics.tier).item,
    );
    final size = look.actionSize!;
    Widget button = Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final lit =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed);
          return CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: radius,
            offset: 1,
            child: SingleMotionBuilder(
              value: lit ? 1 : 0,
              motion: lit ? motion.fade : motion.fadeExit,
              builder: (context, t, _) => Opacity(
                opacity: onPressed == null ? metrics.disabledOpacity : 1,
                child: SizedBox.square(
                  dimension: size,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.hover.withValues(
                        alpha: colors.hover.a * t.clamp(0, 1),
                      ),
                      shape: RoundedSuperellipseBorder(borderRadius: radius),
                    ),
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(
                          size: 16,
                          applyTextScaling: true,
                          color: Color.lerp(
                            colors.mutedForeground,
                            colors.foreground,
                            t.clamp(0, 1),
                          ),
                          weight:
                              CoilIconWeight.rest +
                              (CoilIconWeight.emphasis - CoilIconWeight.rest) *
                                  t.clamp(0, 1),
                        ),
                        child: ExcludeSemantics(child: icon),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (tooltip case final tooltip?) {
      button = CoilTooltip(
        semanticLabel: semanticLabel,
        message: tooltip,
        shortcut: shortcut,
        child: button,
      );
    }
    return button;
  }
}

/// A hairline between sidebar sections.
class CoilSidebarSeparator extends StatelessWidget {
  /// Creates a separator.
  const CoilSidebarSeparator({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: SizedBox(
      height: 1,
      child: ColoredBox(color: CoilTheme.of(context).colors.border),
    ),
  );
}

/// A section of the sidebar: an optional caption [label], [actions] on its
/// row, and [child], usually a sidebar menu.
///
/// Give [onExpandedChanged] to make the label a toggle that folds [child]
/// away. Hovering the label raises its contrast and shows a chevron, which
/// stays while the section is folded; on touch the chevron always shows.
class CoilSidebarGroup extends StatefulWidget {
  /// Creates a group.
  const CoilSidebarGroup({
    required this.child,
    super.key,
    this.label,
    this.semanticLabel,
    this.actions = const [],
    this.expanded = true,
    this.onExpandedChanged,
    this.style,
    this.motion,
  });

  /// The section's caption.
  /// The section's caption, usually a [Text], styled by [DefaultTextStyle].
  final Widget? label;

  /// The caption for screen readers. Null reads the text of a [Text]
  /// [label]; give it for any other widget.
  final String? semanticLabel;

  /// One to three [CoilSidebarAction]s on the label's row, always shown.
  final List<Widget> actions;

  /// Whether [child] shows. Only a group with [onExpandedChanged] folds.
  final bool expanded;

  /// Called with the new [expanded] when the label is pressed. Null keeps
  /// the label a static caption.
  final ValueChanged<bool>? onExpandedChanged;

  /// The section's content.
  final Widget child;

  /// Overrides the theme's sidebar style.
  final CoilSidebarStyle? style;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilSidebarGroup> createState() => _CoilSidebarGroupState();
}

class _CoilSidebarGroupState extends State<CoilSidebarGroup> {
  final _contentId = UniqueKey().toString();

  @override
  Widget build(BuildContext context) {
    final look = _styleOf(context, widget.style);
    final collapsible = widget.onExpandedChanged != null;
    final expanded = !collapsible || widget.expanded;
    final label = widget.label;
    Widget? header;
    if (label != null || widget.actions.isNotEmpty) {
      header = Row(
        children: [
          Expanded(
            child: collapsible && label != null
                ? _GroupToggle(
                    label: label,
                    semanticLabel:
                        widget.semanticLabel ?? coilSidebarPlainText(label),
                    expanded: expanded,
                    contentId: _contentId,
                    look: look,
                    motion: widget.motion,
                    onPressed: () => widget.onExpandedChanged!(!expanded),
                  )
                : _StaticLabel(label: label, look: look),
          ),
          if (widget.actions.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: look.actionGap!,
                end: _trailingInset,
              ),
              child: CoilTooltipGroup(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: look.actionGap!,
                  children: widget.actions,
                ),
              ),
            ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.all(look.padding!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          if (collapsible)
            Semantics(
              identifier: _contentId,
              child: CoilCollapsible(
                expanded: expanded,
                motion: widget.motion,
                child: widget.child,
              ),
            )
          else
            widget.child,
        ],
      ),
    );
  }
}

class _StaticLabel extends StatelessWidget {
  const _StaticLabel({required this.label, required this.look});

  final Widget? label;
  final CoilSidebarStyle look;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: coilSidebarRowHeight(metrics)),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: label == null
              ? null
              : Semantics(
                  header: true,
                  child: DefaultTextStyle(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: look.labelStyle!.copyWith(
                      color: look.labelColor!.resolve({}),
                    ),
                    child: label!,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A collapsible group's label: a toggle with a chevron.
class _GroupToggle extends StatelessWidget {
  const _GroupToggle({
    required this.label,
    required this.semanticLabel,
    required this.expanded,
    required this.contentId,
    required this.look,
    required this.onPressed,
    this.motion,
  });

  final Widget label;
  final String? semanticLabel;
  final bool expanded;
  final String contentId;
  final CoilSidebarStyle look;
  final VoidCallback onPressed;
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.circular(
      theme.shape.radii(metrics.tier).item,
    );
    final touch = metrics.tier == CoilTier.touch;
    return Semantics(
      header: true,
      button: true,
      enabled: true,
      expanded: expanded,
      label: semanticLabel,
      controlsNodes: {contentId},
      child: CoilInteraction(
        onPressed: onPressed,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final lit =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused);
          final color = look.labelColor!.resolve(states)!;
          // Open, the chevron only shows while the label is lit (always on
          // touch); folded, it stays as the cue to reopen.
          final chevron = !expanded || lit || touch;
          return CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: coilSidebarRowHeight(metrics),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: look.labelStyle!.copyWith(color: color),
                        child: ExcludeSemantics(child: label),
                      ),
                    ),
                    if (chevron)
                      SizedBox.square(
                        dimension: look.actionSize,
                        child: SingleMotionBuilder(
                          value: expanded ? 1 : 0,
                          motion: tokens.quick,
                          builder: (context, turn, child) => Transform.rotate(
                            angle: turn * (rtl ? -1 : 1) * 1.5707963,
                            child: child,
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              size: 16,
                              applyTextScaling: true,
                              color: theme.colors.mutedForeground,
                            ),
                            child: const CoilDrawnGlyph(CoilGlyph.chevronEnd),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
