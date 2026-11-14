// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/src/components/breadcrumb/breadcrumb_style.dart';
import 'package:coil/src/components/breadcrumb/crumb.dart';
import 'package:coil/src/components/breadcrumb/crumb_trail.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// One step of a [CoilBreadcrumb].
@immutable
class CoilCrumb {
  /// Creates a crumb.
  const CoilCrumb({required this.label, this.onPressed, this.leading});

  /// The page's name, usually a [Text]. Long names truncate in the trail;
  /// the "…" menu and screen readers get the full name.
  final Widget label;

  /// Goes to the page. Null disables the crumb. The last crumb is the
  /// current page and ignores it.
  final VoidCallback? onPressed;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? leading;
}

/// The animated parts of a [CoilBreadcrumb]. Use them as keys of
/// [CoilBreadcrumb.motions] or [CoilThemeData.trackMotions].
final class CoilBreadcrumbTrack<T extends Object> extends Track<T> {
  CoilBreadcrumbTrack._(super.converter, {required String super.debugLabel});

  /// The hover highlight gliding between crumbs. Default motion: `quick`.
  static final highlight = CoilBreadcrumbTrack<Rect>._(
    .rect,
    debugLabel: 'CoilBreadcrumb.highlight',
  );

  /// The fill under a crumb a finger presses. Default motion: `fade` in,
  /// `fadeExit` out; an override applies to both.
  static final press = CoilBreadcrumbTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilBreadcrumb.press',
  );

  /// The crumb label's color. Default motion: `fade`.
  static final label = CoilBreadcrumbTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilBreadcrumb.label',
  );
}

/// The words a [CoilBreadcrumb] gives screen readers. The defaults are
/// English.
@immutable
class CoilBreadcrumbLabels {
  /// Creates the labels.
  const CoilBreadcrumbLabels({
    this.navigationLabel = 'Breadcrumb',
    this.showHiddenLabel = 'Show hidden pages',
  });

  /// The name of the trail.
  final String navigationLabel;

  /// The name of the "…" button.
  final String showHiddenLabel;

  @override
  bool operator ==(Object other) =>
      other is CoilBreadcrumbLabels &&
      other.navigationLabel == navigationLabel &&
      other.showHiddenLabel == showHiddenLabel;

  @override
  int get hashCode => Object.hash(navigationLabel, showHiddenLabel);
}

/// A trail of links to the current page, which is the last crumb.
///
/// Crumbs are links in Tab order; Enter follows one. The current page is
/// plain text marked `selected`. A chevron, or [separator], follows each
/// link and flips in RTL.
///
/// When the row is too narrow, middle crumbs collapse into "…". The first
/// crumb, the last link and the page always show. On phones the trail
/// always shows the first crumb, "…" and the last two. "…" lists the
/// hidden crumbs by full name.
class CoilBreadcrumb extends StatefulWidget {
  /// Creates a breadcrumb.
  const CoilBreadcrumb({
    required this.crumbs,
    super.key,
    this.separator,
    this.size,
    this.presentation,
    this.labels = const CoilBreadcrumbLabels(),
    this.motion,
    this.motions,
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

  /// The names screen readers hear.
  final CoilBreadcrumbLabels labels;

  /// Overrides the theme's motion tokens for this breadcrumb.
  final CoilMotion? motion;

  /// Per-track motions for this breadcrumb, keyed by
  /// [CoilBreadcrumbTrack]s. They win over the theme's
  /// [CoilThemeData.trackMotions] and [motion].
  final Map<CoilBreadcrumbTrack<Object>, Motion>? motions;

  /// Overrides for this breadcrumb's look.
  final CoilBreadcrumbStyle? style;

  @override
  State<CoilBreadcrumb> createState() => _CoilBreadcrumbState();
}

class _CoilBreadcrumbState extends State<CoilBreadcrumb> {
  final _handle = CrumbTrailHandle();
  final _ellipsisFocus = FocusNode(debugLabel: 'CoilBreadcrumb.more');
  final _menu = CoilPopupController();

  /// One focus gate per trail slot: "…" and each crumb.
  late List<FocusNode> _gates = _gatesFor(widget.crumbs.length + 1);

  static List<FocusNode> _gatesFor(int count) => [
    for (var i = 0; i < count; i++)
      FocusNode(
        debugLabel: 'CoilBreadcrumb.slot$i',
        canRequestFocus: false,
        skipTraversal: true,
      ),
  ];

  @override
  void didUpdateWidget(CoilBreadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = widget.crumbs.length + 1;
    if (_gates.length != count) {
      for (final gate in _gates) {
        gate.dispose();
      }
      _gates = _gatesFor(count);
    }
  }

  @override
  void dispose() {
    _menu.dispose();
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

  Motion _motionFor(
    BuildContext context,
    CoilBreadcrumbTrack<Object> track,
    Motion token,
  ) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: track == CoilBreadcrumbTrack.highlight,
  );

  void _openMenu() {
    if (_handle.hidden > 0) unawaited(_menu.open());
  }

  /// Wraps "…" in the menu of the crumbs it hides.
  Widget _withMenu(CoilBreadcrumbStyle trailStyle, Widget ellipsis) =>
      CoilAdaptivePopup(
        controller: _menu,
        presentation: widget.presentation,
        motion: widget.motion,
        traits: () => CoilOverlayTraits(
          kind: CoilOverlayKind.actionMenu,
          itemCount: _handle.hidden,
        ),
        maxHeight: trailStyle.menuMaxHeight!,
        content: (context, popup) {
          final theme = CoilTheme.of(context);
          // A sheet is a touch surface whatever the tier.
          final metrics = popup.presentation == CoilPresentation.sheet
              ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
              : CoilTheme.metricsOf(context);
          final style = _style(context, metrics);
          final scroll = CoilScrollAreaStyle.fallback(
            theme,
            metrics,
          ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
          return MotorInspectionScope(
            group: 'CoilBreadcrumb',
            child: CoilActionList(
              entries: [
                for (final crumb in widget.crumbs.sublist(
                  1,
                  1 + _handle.hidden,
                ))
                  CoilAction(
                    label: crumb.label,
                    leading: crumb.leading,
                    onPressed: crumb.onPressed,
                  ),
              ],
              onClose: popup.close,
              metrics: metrics,
              surface: popup.presentation == CoilPresentation.sheet
                  ? theme.colors.surface(3)
                  : style.surface!,
              scrollbar: scroll.scrollbarLook,
              fadeExtent: scroll.fadeExtent!,
              highlight: style.highlight,
              pressFill: style.pressFill,
              radius: style.radius,
              motion: widget.motion,
            ),
          );
        },
        popover: (context, content) {
          final metrics = CoilTheme.metricsOf(context);
          final style = _style(context, metrics);
          return CoilPopoverSurface(
            color: style.surface,
            radius: style.radius! + metrics.popupInset,
            minWidth: metrics.triggerMinWidth,
            child: content,
          );
        },
        sheet: (context, content) => CoilSheetPanel(child: content),
        child: ellipsis,
      );

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(
      context,
      size:
          widget.size ??
          CoilAdaptiveScope.maybeSizeOf(context) ??
          CoilSize.compact,
    );
    final style = _style(context, metrics);
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final motions = CrumbMotions(
      pressIn: _motionFor(context, CoilBreadcrumbTrack.press, tokens.fade),
      pressOut: _motionFor(
        context,
        CoilBreadcrumbTrack.press,
        tokens.fadeExit,
      ),
      label: _motionFor(context, CoilBreadcrumbTrack.label, tokens.fade),
    );
    final phone =
        CoilTheme.tierOf(context) == CoilTier.touch &&
        MediaQuery.sizeOf(context).width < CoilAdaptivePopup.compactWidth;
    final separator =
        widget.separator ?? const CoilDrawnGlyph(CoilGlyph.chevronEnd);
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
        label: widget.labels.navigationLabel,
        explicitChildNodes: true,
        child: CoilHoverRegion(
          axis: CoilHoverAxis.x,
          followFocus: false,
          child: CoilHoverHighlight(
            color: style.highlight,
            radius: style.radius,
            motion: widget.motion,
            glideMotion: _motionFor(
              context,
              CoilBreadcrumbTrack.highlight,
              tokens.quick,
            ),
            child: CrumbTrail(
              collapse: phone ? CrumbCollapse.always : CrumbCollapse.overflow,
              handle: _handle,
              gates: _gates,
              children: [
                slot(
                  0,
                  _withMenu(
                    style,
                    CrumbLink(
                      index: widget.crumbs.length,
                      label: const Text('…'),
                      semanticLabel: widget.labels.showHiddenLabel,
                      link: false,
                      focusNode: _ellipsisFocus,
                      onPressed: _openMenu,
                      separator: separator,
                      metrics: metrics,
                      motions: motions,
                      style: style,
                    ),
                  ),
                ),
                for (final (i, crumb) in widget.crumbs.indexed)
                  slot(
                    i + 1,
                    i == last
                        ? CrumbPage(
                            label: crumb.label,
                            leading: crumb.leading,
                            metrics: metrics,
                            style: style,
                          )
                        : CrumbLink(
                            index: i,
                            label: crumb.label,
                            leading: crumb.leading,
                            onPressed: crumb.onPressed,
                            separator: separator,
                            metrics: metrics,
                            motions: motions,
                            style: style,
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
