// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/breadcrumb/breadcrumb_style.dart';
import 'package:coil/src/components/breadcrumb/crumb_trail.dart';
import 'package:coil/src/components/breadcrumb/hidden_crumbs.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// One step of a [CoilBreadcrumb].
@immutable
class CoilCrumb {
  /// Creates a crumb.
  const CoilCrumb({required this.label, this.onPressed, this.icon});

  /// The page's name. Long names truncate in the trail; the "…" menu and
  /// semantics always have the full name.
  final String label;

  /// Goes to the page. Null disables the crumb. The last crumb is the
  /// current page and ignores it.
  final VoidCallback? onPressed;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? icon;
}

/// A trail of links to the current page, which is the last crumb.
///
/// Crumbs are links in Tab order; Enter follows one. The current page is
/// plain text marked `selected`. Each link ends in a separator, a chevron
/// by default (mirrored in RTL) or [separator].
///
/// When the row is too narrow, middle crumbs collapse into "…", decided in
/// layout: the first crumb, the last link and the page always show. On
/// phones (touch tier, a window narrower than 600) the trail always
/// collapses to the first crumb, "…" and the last two. "…" opens a menu,
/// or a sheet when it is long, that lists the hidden crumbs by full name.
///
/// Crumbs default to the compact size: 28 high on the pointer tier, 36 on
/// touch with a 44 hit target.
class CoilBreadcrumb extends StatefulWidget {
  /// Creates a breadcrumb.
  const CoilBreadcrumb({
    required this.crumbs,
    super.key,
    this.separator,
    this.size,
    this.presentation,
    this.motion,
    this.style,
  }) : assert(crumbs.length > 0, 'a breadcrumb needs the current page');

  /// The trail, from the root to the current page.
  final List<CoilCrumb> crumbs;

  /// Replaces the chevron after each link. It isn't mirrored in RTL.
  final Widget? separator;

  /// Pins the crumbs to one size step. Null follows [CoilAdaptiveScope],
  /// else [CoilSize.compact].
  final CoilSize? size;

  /// How the "…" menu opens. Null lets [CoilAdaptivePopup] decide.
  final CoilPresentation? presentation;

  /// Overrides the theme's motion tokens for this breadcrumb.
  final CoilMotion? motion;

  /// Overrides for this breadcrumb's look.
  final CoilBreadcrumbStyle? style;

  @override
  State<CoilBreadcrumb> createState() => _CoilBreadcrumbState();
}

class _CoilBreadcrumbState extends State<CoilBreadcrumb> {
  final _handle = CrumbTrailHandle();
  final _ellipsisFocus = FocusNode(debugLabel: 'CoilBreadcrumb.more');
  final _ellipsisAnchor = GlobalKey(debugLabel: 'CoilBreadcrumb.more');
  List<FocusNode> _gates = [];
  CoilPopupHandle? _popup;

  void _syncGates() {
    final count = widget.crumbs.length + 1;
    if (_gates.length == count) return;
    for (final gate in _gates) {
      gate.dispose();
    }
    _gates = [
      for (var i = 0; i < count; i++)
        FocusNode(
          debugLabel: 'CoilBreadcrumb.slot$i',
          canRequestFocus: false,
          skipTraversal: true,
        ),
    ];
  }

  @override
  void dispose() {
    _popup?.close(CoilPopupCloseReason.programmatic);
    for (final gate in _gates) {
      gate.dispose();
    }
    _ellipsisFocus.dispose();
    super.dispose();
  }

  CoilBreadcrumbStyle _style(BuildContext context, CoilMetrics metrics) =>
      CoilBreadcrumbStyle.fallback(CoilTheme.of(context), metrics)
          .merge(CoilTheme.styleOf<CoilBreadcrumbStyle>(context))
          .merge(widget.style);

  Future<void> _openMenu() async {
    final anchor = _ellipsisAnchor.currentContext;
    final hidden = _handle.hidden;
    if (_popup != null || anchor == null || hidden == 0) return;
    final crumbs = widget.crumbs.sublist(1, 1 + hidden);
    final presentation = CoilAdaptivePopup.presentationOf(
      anchor,
      override: widget.presentation,
      traits: CoilOverlayTraits(
        kind: CoilOverlayKind.actionMenu,
        itemCount: crumbs.length,
      ),
    );
    final sheet = presentation == CoilPresentation.sheet;
    final pointer = CoilTheme.tierOf(anchor) == CoilTier.pointer;
    // A sheet is a touch surface whatever the tier.
    final metrics = sheet
        ? CoilMetrics.resolve(CoilTier.touch, CoilSize.regular)
        : CoilTheme.metricsOf(anchor);
    final style = _style(anchor, metrics);
    final line = MediaQuery.textScalerOf(anchor).scale(metrics.body.lineHeight);
    final rowExtent = metrics.controlHeight - metrics.body.lineHeight + line;
    final keyboard = CoilInputModality.instance.value == CoilModality.keyboard;

    final popup = _popup = CoilAdaptivePopup.show(
      anchor,
      presentation: presentation,
      estimatedHeight: crumbs.length * rowExtent + metrics.popupInset * 2,
      maxHeight: pointer && !sheet ? 480 : double.infinity,
      content: (context, popup) => MotorInspectionScope(
        group: 'CoilBreadcrumb',
        child: HiddenCrumbList(
          crumbs: [
            for (final crumb in crumbs)
              HiddenCrumb(
                label: crumb.label,
                icon: crumb.icon,
                onPressed: crumb.onPressed,
              ),
          ],
          metrics: metrics,
          style: style,
          fullEmphasis: sheet || !pointer,
          keyboardOpened: keyboard,
          // An action closes the menu at once, then runs.
          onPick: (i) {
            popup.close(CoilPopupCloseReason.selected);
            crumbs[i].onPressed?.call();
          },
          onDismiss: popup.close,
        ),
      ),
      popover: (context, content) =>
          _MenuSurface(metrics: metrics, style: style, child: content),
      sheet: (context, content) => CoilSheetPanel(child: content),
    );
    final reason = await popup.closed;
    _popup = null;
    if (mounted && reason != CoilPopupCloseReason.selected) {
      _ellipsisFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.motion;
    if (override == null) return _build(context);
    return CoilTheme.override(
      transform: (t) => t.copyWith(motion: override),
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    _syncGates();
    final metrics = CoilTheme.metricsOf(
      context,
      size:
          widget.size ??
          CoilAdaptiveScope.maybeSizeOf(context) ??
          CoilSize.compact,
    );
    final style = _style(context, metrics);
    final phone =
        CoilTheme.tierOf(context) == CoilTier.touch &&
        MediaQuery.sizeOf(context).width < CoilAdaptivePopup.compactWidth;
    final separator = widget.separator ?? const _Chevron();
    final last = widget.crumbs.length - 1;

    Widget slot(int index, Widget child) => Focus.withExternalFocusNode(
      focusNode: _gates[index],
      includeSemantics: false,
      child: child,
    );

    return MotorInspectionScope(
      group: 'CoilBreadcrumb',
      child: Semantics(
        container: true,
        role: SemanticsRole.navigation,
        label: 'Breadcrumb',
        explicitChildNodes: true,
        child: CoilHoverRegion(
          axis: CoilHoverAxis.x,
          followFocus: false,
          highlightColor: style.highlight,
          highlightRadius: style.radius,
          child: CrumbTrail(
            collapse: phone ? CrumbCollapse.always : CrumbCollapse.overflow,
            handle: _handle,
            gates: _gates,
            children: [
              slot(
                0,
                _Crumb(
                  index: widget.crumbs.length,
                  label: '…',
                  semanticLabel: 'Show hidden pages',
                  link: false,
                  anchorKey: _ellipsisAnchor,
                  focusNode: _ellipsisFocus,
                  onPressed: () => unawaited(_openMenu()),
                  separator: separator,
                  metrics: metrics,
                  style: style,
                ),
              ),
              for (final (i, crumb) in widget.crumbs.indexed)
                slot(
                  i + 1,
                  i == last
                      ? _CurrentPage(
                          crumb: crumb,
                          metrics: metrics,
                          style: style,
                        )
                      : _Crumb(
                          index: i,
                          label: crumb.label,
                          icon: crumb.icon,
                          onPressed: crumb.onPressed,
                          separator: separator,
                          metrics: metrics,
                          style: style,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A link crumb (or "…"): the label and its trailing separator in one
/// pressable box, which the trail's highlight glides between.
class _Crumb extends StatefulWidget {
  const _Crumb({
    required this.index,
    required this.label,
    required this.onPressed,
    required this.separator,
    required this.metrics,
    required this.style,
    this.icon,
    this.semanticLabel,
    this.link = true,
    this.focusNode,
    this.anchorKey,
  });

  final int index;
  final String label;
  final String? semanticLabel;
  final Widget? icon;
  final VoidCallback? onPressed;
  final Widget separator;
  final CoilMetrics metrics;
  final CoilBreadcrumbStyle style;
  final bool link;
  final FocusNode? focusNode;
  final Key? anchorKey;

  @override
  State<_Crumb> createState() => _CrumbState();
}

class _CrumbState extends State<_Crumb> {
  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final motion = CoilTheme.motionOf(context);
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(style.radius!);
    return Semantics(
      link: widget.link,
      button: !widget.link,
      label: widget.semanticLabel,
      child: CoilInteraction(
        onPressed: widget.onPressed,
        focusNode: widget.focusNode,
        minHitTarget: widget.metrics.minHitTarget,
        builder: (context, states, _) {
          final focused = states.contains(WidgetState.focused);
          final pressed = states.contains(WidgetState.pressed);
          final hovering = states.contains(WidgetState.hovered);
          final lit =
              focused ||
              pressed ||
              CoilHoverRegion.maybeOf(context)?.activeIndex == widget.index;
          final color = style.label!.resolve({
            if (lit) WidgetState.hovered,
            if (!enabled) WidgetState.disabled,
          })!;
          // A finger gets a fill while it presses; a hovering pointer
          // already shows the highlight.
          final fill = pressed && !hovering
              ? style.pressFill!
              : style.pressFill!.withValues(alpha: 0);
          return Opacity(
            opacity: enabled ? 1 : 0.5,
            child: CoilHoverItem(
              key: widget.anchorKey,
              index: widget.index,
              enabled: enabled,
              child: CoilFocusRing(
                visible: focused,
                borderRadius: radius,
                offset: 1,
                child: MotionBuilder<Color>(
                  value: fill,
                  converter: MotionConverter.colorRgb,
                  motion: pressed ? motion.fade : motion.fadeExit,
                  debugLabel: 'CoilBreadcrumb press',
                  builder: (context, fill, child) => DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: RoundedSuperellipseBorder(borderRadius: radius),
                    ),
                    child: child,
                  ),
                  child: MotionBuilder<Color>(
                    value: color,
                    converter: MotionConverter.colorRgb,
                    motion: motion.fade,
                    debugLabel: 'CoilBreadcrumb label',
                    builder: (context, color, _) => _CrumbContent(
                      label: widget.label,
                      labelInSemantics: widget.semanticLabel == null,
                      icon: widget.icon,
                      color: color,
                      lit: lit,
                      separator: widget.separator,
                      metrics: widget.metrics,
                      style: style,
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
class _CurrentPage extends StatelessWidget {
  const _CurrentPage({
    required this.crumb,
    required this.metrics,
    required this.style,
  });

  final CoilCrumb crumb;
  final CoilMetrics metrics;
  final CoilBreadcrumbStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: true,
    child: _CrumbContent(
      label: crumb.label,
      icon: crumb.icon,
      color: style.label!.resolve({WidgetState.selected})!,
      lit: false,
      separator: null,
      metrics: metrics,
      style: style,
    ),
  );
}

/// [icon] label [separator], at least the crumb height, with the label
/// truncating when the trail gives it less than its width.
class _CrumbContent extends StatelessWidget {
  const _CrumbContent({
    required this.label,
    required this.icon,
    required this.color,
    required this.lit,
    required this.separator,
    required this.metrics,
    required this.style,
    this.labelInSemantics = true,
  });

  final String label;
  final bool labelInSemantics;
  final Widget? icon;
  final Color color;
  final bool lit;
  final Widget? separator;
  final CoilMetrics metrics;
  final CoilBreadcrumbStyle style;

  @override
  Widget build(BuildContext context) {
    final minHeight = style.minHeight!;
    final padY = (minHeight - metrics.body.lineHeight) / 2;
    final padX = style.paddingX!;
    final separator = this.separator;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        // The separator glyph has its own side bearing, so the crumb's end
        // padding shrinks next to it.
        padding: EdgeInsetsDirectional.fromSTEB(
          padX,
          padY,
          separator == null ? padX : 2,
          padY,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  color: color,
                  weight: lit ? CoilIconWeight.emphasis : CoilIconWeight.rest,
                  applyTextScaling: true,
                ),
                child: icon,
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
              const SizedBox(width: 2),
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
    );
  }
}

/// The "…" menu's popover surface: surface 3, shadow 3, concentric with
/// its rows.
class _MenuSurface extends StatelessWidget {
  const _MenuSurface({
    required this.metrics,
    required this.style,
    required this.child,
  });

  final CoilMetrics metrics;
  final CoilBreadcrumbStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(style.radius! + metrics.popupInset);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: metrics.triggerMinWidth),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: style.surface,
            shadows: colors.shadow(3),
            shape: RoundedSuperellipseBorder(borderRadius: radius),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: colors.insetRing(3),
              ),
            ),
            child: ClipRSuperellipse(borderRadius: radius, child: child),
          ),
        ),
      ),
    );
  }
}

/// The default separator: a chevron pointing to the next crumb, so it
/// flips in RTL. Drawn in the [IconTheme]'s size and color.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(CoilIconSize.of(context)),
    painter: _ChevronPainter(
      color: IconTheme.of(context).color ?? const Color(0xFF000000),
      rtl: Directionality.of(context) == TextDirection.rtl,
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter({required this.color, required this.rtl});

  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    double x(double v) => (rtl ? 24 - v : v) * s;
    canvas.drawPath(
      Path()
        ..moveTo(x(9), 6 * s)
        ..lineTo(x(15), 12 * s)
        ..lineTo(x(9), 18 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.rtl != rtl;
}
