// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/src/components/banner/banner_kinds.dart';
import 'package:coil/src/components/banner/banner_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilBanner]. Use them as keys of
/// [CoilBanner.motions] or [CoilThemeData.trackMotions].
final class CoilBannerTrack<T extends Object> extends Track<T> {
  CoilBannerTrack._(super.converter, {required String super.debugLabel});

  /// How open the banner's row is, 0 to 1. Default motion: `standard`
  /// opening, `standardExit` closing.
  static final row = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.row',
  );

  /// The banner's scale, 0.4 to 1, from its top edge. Default motion:
  /// `gentle` in, `gentleExit` out.
  static final scale = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.scale',
  );

  /// The banner's opacity. Default motion: `fade` in, `fadeExit` out.
  static final opacity = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.opacity',
  );

  /// The horizontal offset of a touch swipe, in logical pixels. Default
  /// motion: `standard` back to rest, `standardExit` away.
  static final swipe = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.swipe',
  );
}

/// A status message with an optional icon, actions and a dismiss button.
///
/// The banner is controlled by [visible]: set it to false and the banner
/// shrinks, fades and then closes its row; set it to true and the row opens
/// before the banner fades and grows in. It animates only on changes, so a
/// banner built visible shows at once. To animate one in, build it with
/// `visible: false` and then flip it. A hidden banner takes no space and
/// is skipped by focus, semantics and hit testing.
///
/// [onDismissed] adds the dismiss button and, on touch, a horizontal swipe.
/// Both only report the request: set [visible] to false in response.
///
/// The banner is a polite live region, so screen readers announce it when
/// it appears.
class CoilBanner extends StatefulWidget {
  /// Creates a banner.
  const CoilBanner({
    required this.title,
    super.key,
    this.description,
    this.icon,
    this.actions = const [],
    this.onDismissed,
    this.dismissIcon,
    this.status = CoilBannerStatus.neutral,
    this.variant = CoilBannerVariant.plain,
    this.placement = CoilBannerPlacement.inline,
    this.visible = true,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The message, in semibold body text. Wraps.
  final Widget title;

  /// More detail under the title, in muted body text. Wraps.
  final Widget? description;

  /// A status glyph, sized by [IconTheme] and colored with the status hue.
  /// It sits in a box one title line tall.
  final Widget? icon;

  /// Buttons for the banner, usually `CoilButton`s. They are shown at the
  /// compact size, after the title or under the description.
  final List<Widget> actions;

  /// Called when the user asks to dismiss the banner, with the dismiss
  /// button or a touch swipe. Null hides the button and turns off the
  /// swipe.
  final VoidCallback? onDismissed;

  /// Replaces the dismiss button's drawn ✕.
  final Widget? dismissIcon;

  /// What the banner reports.
  final CoilBannerStatus status;

  /// How strongly the fill shows the [status].
  final CoilBannerVariant variant;

  /// In the page flow, or a full-width bar at the top.
  final CoilBannerPlacement placement;

  /// Whether the banner is shown. Changes animate.
  final bool visible;

  /// Pins the banner to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this banner.
  final CoilMotion? motion;

  /// Per-track motions for this banner, keyed by [CoilBannerTrack]s. They
  /// win over the theme's [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilBannerTrack<Object>, Motion>? motions;

  /// Overrides for this banner's look.
  final CoilBannerStyle? style;

  @override
  State<CoilBanner> createState() => _CoilBannerState();
}

/// The appear and dismiss stagger: the row leads the banner by this much
/// on the way in and trails it on the way out.
const _stagger = Duration(milliseconds: 80);

/// How far ahead a swipe release is projected (`x + v·t`) to decide it.
const _projection = 0.1;

class _CoilBannerState extends State<CoilBanner>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(
    vsync: this,
    debugLabel: 'CoilBanner',
  );
  final _scope = FocusNode(
    debugLabel: 'CoilBanner',
    canRequestFocus: false,
    skipTraversal: true,
  );

  final _row = CoilBannerTrack.row;
  final _scale = CoilBannerTrack.scale;
  final _opacity = CoilBannerTrack.opacity;
  final _swipe = CoilBannerTrack.swipe;

  bool _dragging = false;
  double _width = 1;

  CoilMotion get _tokens =>
      CoilTheme.motionOf(context, override: widget.motion);

  Motion _motionFor(
    CoilBannerTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

  @override
  void initState() {
    super.initState();
    final shown = widget.visible ? 1.0 : 0.0;
    _controller.set([
      _row.value(shown),
      _opacity.value(shown),
      _scale.value(widget.visible ? 1 : 0.4),
      _swipe.value(0),
    ]);
  }

  @override
  void didUpdateWidget(CoilBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    widget.visible ? _appear() : _dismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _appear() {
    final m = _tokens;
    _dragging = false;
    _controller
      ..set([_swipe.value(0)])
      ..animate([
        _row([.to(1, motion: _motionFor(_row, m.standard))]),
        _scale([.to(1, motion: _motionFor(_scale, m.gentle))], delay: _stagger),
        _opacity([
          .to(1, motion: _motionFor(_opacity, m.fade, spatial: false)),
        ], delay: _stagger),
      ]);
  }

  void _dismiss() {
    // Focus inside a closing banner moves on to what follows it, as it
    // would if the banner had never been there.
    if (_scope.hasFocus) {
      (_scope.traversalDescendants.lastOrNull ??
              FocusManager.instance.primaryFocus)
          ?.nextFocus();
    }
    final m = _tokens;
    _dragging = false;
    _controller.animate([
      _opacity([
        .to(0, motion: _motionFor(_opacity, m.fadeExit, spatial: false)),
      ]),
      _scale([.to(0.4, motion: _motionFor(_scale, m.gentleExit))]),
      _row([
        .to(0, motion: _motionFor(_row, m.standardExit)),
      ], delay: _stagger),
    ]);
  }

  void _dragStart(DragStartDetails _) {
    _width = context.size?.width ?? 1;
    _dragging = true;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _controller.set([
      _swipe.value(_controller.value(_swipe) + details.delta.dx),
    ]);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final m = _tokens;
    final x = _controller.value(_swipe);
    final v = details.velocity.pixelsPerSecond.dx;
    final projected = x + v * _projection;
    if (projected.abs() < _width / 2) {
      _controller.animate([
        _swipe([
          .to(0, motion: _motionFor(_swipe, m.standard)),
        ], withVelocity: v),
      ]);
      return;
    }
    final away = _controller.animate([
      _swipe([
        .to(
          projected.sign * _width,
          motion: _motionFor(_swipe, m.standardExit),
        ),
      ], withVelocity: v),
    ]);
    widget.onDismissed?.call();
    // If the owner keeps the banner, it springs back.
    away.ended.then((_) {
      if (mounted && widget.visible && !_dragging) {
        _controller.animate([
          _swipe([.to(0, motion: _motionFor(_swipe, _tokens.standard))]),
        ]);
      }
    }).ignore();
  }

  void _dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _controller.animate([
      _swipe([.to(0, motion: _motionFor(_swipe, _tokens.standard))]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilBannerStyle.fallback(
      theme,
      metrics,
      status: widget.status,
      variant: widget.variant,
      placement: widget.placement,
    ).merge(CoilTheme.styleOf<CoilBannerStyle>(context)).merge(widget.style);
    final fixed = widget.placement == CoilBannerPlacement.fixed;
    final media = MediaQuery.of(context);

    Widget surface = DecoratedBox(
      decoration: ShapeDecoration(
        color: style.background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(style.radius!),
        ),
      ),
      child: Padding(
        padding: fixed
            ? EdgeInsets.only(
                top: media.padding.top,
                left: media.padding.left,
                right: media.padding.right,
              )
            : EdgeInsets.zero,
        child: _BannerContent(
          style: style,
          metrics: metrics,
          title: widget.title,
          description: widget.description,
          icon: widget.icon,
          actions: widget.actions,
          onDismissed: widget.onDismissed,
          dismissIcon: widget.dismissIcon,
        ),
      ),
    );

    if (widget.onDismissed != null && widget.visible) {
      surface = GestureDetector(
        // A swipe is a touch gesture; a mouse drag selects or does nothing.
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
        excludeFromSemantics: true,
        onHorizontalDragStart: _dragStart,
        onHorizontalDragUpdate: _dragUpdate,
        onHorizontalDragEnd: _dragEnd,
        onHorizontalDragCancel: _dragCancel,
        child: surface,
      );
    }

    // Web screen readers have an assertive role for alerts; elsewhere a
    // live region (polite) is all Flutter offers, so destructive banners
    // are polite there.
    final alert = kIsWeb && widget.status == CoilBannerStatus.destructive;
    surface = Semantics(
      container: true,
      liveRegion: !alert,
      role: alert ? SemanticsRole.alert : null,
      child: surface,
    );

    return MotorInspectionScope(
      group: 'CoilBanner',
      child: Focus(
        focusNode: _scope,
        includeSemantics: false,
        child: ExcludeFocus(
          excluding: !widget.visible,
          child: ExcludeSemantics(
            excluding: !widget.visible,
            child: IgnorePointer(
              ignoring: !widget.visible,
              child: ListenableBuilder(
                listenable: _controller,
                child: surface,
                builder: (context, child) {
                  final row = _controller.value(_row).clamp(0.0, 1.0);
                  final swipe = _controller.value(_swipe);
                  final opacity =
                      _controller.value(_opacity).clamp(0.0, 1.0) *
                      (1 - swipe.abs() / _width).clamp(0.0, 1.0);
                  return ClipRect(
                    // Clip only while the row is partly open, so a bouncy
                    // scale can overshoot once it is.
                    clipBehavior: row < 1 ? Clip.hardEdge : Clip.none,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: row,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(swipe, 0),
                          child: Transform.scale(
                            scale: _controller.value(_scale),
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The banner's layout: [icon] text [actions] [✕]. With a description,
/// the actions move under the text.
class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.style,
    required this.metrics,
    required this.title,
    required this.description,
    required this.icon,
    required this.actions,
    required this.onDismissed,
    required this.dismissIcon,
  });

  final CoilBannerStyle style;
  final CoilMetrics metrics;
  final Widget title;
  final Widget? description;
  final Widget? icon;
  final List<Widget> actions;
  final VoidCallback? onDismissed;
  final Widget? dismissIcon;

  @override
  Widget build(BuildContext context) {
    final pad = style.padding!;
    final gap = style.gap!;
    final scaler = MediaQuery.textScalerOf(context);
    final titleLine = scaler.scale(metrics.body.lineHeight);
    final stacked = description != null;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle(style: style.titleStyle!, child: title),
        if (description case final description?)
          DefaultTextStyle(style: style.descriptionStyle!, child: description),
      ],
    );
    final buttons = actions.isEmpty
        ? null
        : CoilAdaptiveScope(
            size: CoilSize.compact,
            child: Wrap(spacing: 8, runSpacing: 8, children: actions),
          );

    final main = Row(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (icon case final icon?) ...[
          SizedBox(
            height: titleLine,
            child: Center(
              widthFactor: 1,
              child: ExcludeSemantics(
                child: IconTheme(
                  data: IconThemeData(
                    size: style.iconSize,
                    color: style.statusColor,
                    applyTextScaling: true,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
          SizedBox(width: gap),
        ],
        Expanded(
          child: stacked && buttons != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: 8), buttons],
                )
              : text,
        ),
        if (!stacked && buttons != null) ...[SizedBox(width: gap), buttons],
      ],
    );

    final dismiss = onDismissed;
    if (dismiss == null) {
      return Padding(padding: EdgeInsets.all(pad), child: main);
    }

    // The ✕ is a compact ghost button. Its box is centered on the title
    // line and its glyph lines up with the padding edge.
    final buttonMetrics = const CoilMetricsTable().resolve(
      metrics.tier,
      CoilSize.compact,
    );
    final box = buttonMetrics.controlHeight > buttonMetrics.minHitTarget
        ? buttonMetrics.controlHeight
        : buttonMetrics.minHitTarget;
    final glyph = scaler.scale(buttonMetrics.iconSize);
    final clearance = (box - glyph) / 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              pad,
              pad,
              (gap - clearance).clamp(0, gap),
              pad,
            ),
            child: main,
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: (pad + titleLine / 2 - box / 2).clamp(0, pad),
            end: (pad - clearance).clamp(0, pad),
          ),
          child: CoilButton.icon(
            onPressed: dismiss,
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            semanticLabel: 'Dismiss',
            icon: dismissIcon ?? const _DismissGlyph(),
          ),
        ),
      ],
    );
  }
}

/// The default ✕, drawn in the [IconTheme]'s size and color.
class _DismissGlyph extends StatelessWidget {
  const _DismissGlyph();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(CoilIconSize.of(context)),
    painter: _DismissPainter(
      IconTheme.of(context).color ?? const Color(0xFF000000),
    ),
  );
}

class _DismissPainter extends CustomPainter {
  _DismissPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(6 * s, 6 * s), Offset(18 * s, 18 * s), paint)
      ..drawLine(Offset(18 * s, 6 * s), Offset(6 * s, 18 * s), paint);
  }

  @override
  bool shouldRepaint(_DismissPainter old) => old.color != color;
}
