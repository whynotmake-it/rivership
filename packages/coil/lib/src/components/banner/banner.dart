// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

/// @docImport 'package:coil/button.dart';
library;

import 'package:coil/foundation.dart';
import 'package:coil/src/components/banner/banner_content.dart';
import 'package:coil/src/components/banner/banner_kinds.dart';
import 'package:coil/src/components/banner/banner_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilBanner].
///
/// Use these as keys of [CoilBanner.motions] or [CoilBannerStyle.motions].
final class CoilBannerTrack<T extends Object> extends Track<T> {
  CoilBannerTrack._(super.converter, {required String super.debugLabel});

  /// How open the banner's row is, from 0 to 1.
  ///
  /// Defaults to [CoilMotion.standard] opening and [CoilMotion.standardExit]
  /// closing.
  static final row = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.row',
  );

  /// The room of the description and its size as it changes, so the banner
  /// grows and shrinks to fit it.
  ///
  /// Defaults to [CoilMotion.standard] growing and [CoilMotion.standardExit]
  /// shrinking; the text fades on [CoilMotion.fade] and [CoilMotion.fadeExit].
  static final size = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.size',
  );

  /// The banner's scale, from 0.4 to 1, anchored at its top edge.
  ///
  /// Defaults to [CoilMotion.gentle] in and [CoilMotion.gentleExit] out.
  static final scale = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.scale',
  );

  /// The banner's opacity.
  ///
  /// Defaults to [CoilMotion.fade] in and [CoilMotion.fadeExit] out.
  static final opacity = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.opacity',
  );

  /// The horizontal offset of a touch swipe, in logical pixels.
  ///
  /// Defaults to [CoilMotion.standard] back to rest and
  /// [CoilMotion.standardExit] away.
  static final swipe = CoilBannerTrack<double>._(
    .single,
    debugLabel: 'CoilBanner.swipe',
  );
}

/// A status message with an optional icon, actions, and a dismiss button.
///
/// The banner is controlled by [visible]: set it to false and the banner
/// shrinks, fades and then closes its row; set it to true and the row opens
/// before the banner fades and grows in. It animates only on changes, so a
/// banner built visible shows at once. To animate one in, build it with
/// `visible: false` and then flip it. A hidden banner takes no space and
/// is skipped by focus, semantics and hit testing.
///
/// [onDismissRequested] adds the dismiss button and, on touch, a
/// horizontal swipe. Both only report the request: set [visible] to false
/// in response.
///
/// A description that comes, goes or changes never makes the banner jump: it
/// springs to its new size ([CoilBannerTrack.size]). The actions move under
/// the text as soon as a description arrives, and back beside it once a
/// leaving one has closed; that step is a change of layout, not a spring.
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
    this.onDismissRequested,
    this.dismissIcon,
    this.dismissLabel = 'Dismiss',
    this.status = CoilBannerStatus.neutral,
    this.variant = CoilBannerVariant.plain,
    this.placement = CoilBannerPlacement.inline,
    this.visible = true,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The message, in semibold body text.
  ///
  /// Wraps to multiple lines when needed.
  final Widget title;

  /// More detail under the title, in muted body text.
  ///
  /// Wraps to multiple lines when needed.
  final Widget? description;

  /// A status glyph, sized by [IconTheme] and colored with the status hue.
  ///
  /// Sits in a box one title line tall.
  final Widget? icon;

  /// Buttons for the banner, usually [CoilButton] widgets.
  ///
  /// Shown at the compact size, after the title or under the description.
  final List<Widget> actions;

  /// Called when the user asks to dismiss the banner, with the dismiss
  /// button or a touch swipe.
  ///
  /// When null, hides the button and disables the swipe.
  final VoidCallback? onDismissRequested;

  /// Replaces the dismiss button's ✕: the theme's [CoilIcons.close], or
  /// Coil's drawn one.
  final Widget? dismissIcon;

  /// The dismiss button's name for assistive technology.
  final String dismissLabel;

  /// What the banner reports.
  final CoilBannerStatus status;

  /// How strongly the fill shows the [status].
  final CoilBannerVariant variant;

  /// In the page flow, or a full-width bar at the top.
  final CoilBannerPlacement placement;

  /// Whether the banner is shown.
  ///
  /// Changes animate.
  final bool visible;

  /// Pins the banner to one size step.
  ///
  /// When null, follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this banner.
  final CoilMotion? motion;

  /// Per-track motions for this banner, keyed by [CoilBannerTrack] values.
  ///
  /// These take precedence over [CoilBannerStyle.motions] and the theme
  /// tokens.
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
    with SingleFixedTickerProviderStateMixin {
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
  final _size = CoilBannerTrack.size;

  bool _dragging = false;
  double _width = 1;

  /// Whether the actions are under the text: with a description, and until a
  /// leaving one has closed.
  bool _stacked = false;

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
    styled:
        (CoilTheme.styleOf<CoilBannerStyle>(context)?.merge(widget.style) ??
                widget.style)
            ?.motions,
    token: token,
    spatial: spatial,
  );

  @override
  void initState() {
    super.initState();
    final shown = widget.visible ? 1.0 : 0.0;
    _stacked = widget.description != null;
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
    if (widget.description != null) _stacked = true;
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
    widget.onDismissRequested?.call();
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
    final content = BannerContent(
      style: style,
      title: widget.title,
      description: widget.description,
      icon: widget.icon,
      actions: widget.actions,
      onDismissRequested: widget.onDismissRequested,
      dismissIcon: widget.dismissIcon,
      dismissLabel: widget.dismissLabel,
      stacked: _stacked,
      motion: widget.motion,
      sizeMotion: _motionFor(_size, _tokens.standard),
      sizeExitMotion: _motionFor(_size, _tokens.standardExit),
      onDescriptionEnd: () {
        if (widget.description == null && _stacked) {
          setState(() => _stacked = false);
        }
      },
    );

    Widget surface = DecoratedBox(
      decoration: ShapeDecoration(
        color: style.background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(style.radius!),
        ),
      ),
      child: fixed ? SafeArea(bottom: false, child: content) : content,
    );

    if (widget.onDismissRequested != null && widget.visible) {
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
