// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input_copy/input_copy_style.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// How a [CoilInputCopy] shows its copy action.
enum CoilInputCopyVariant {
  /// The copy icon alone.
  icon,

  /// The copy icon with a "Copy" label.
  button,
}

/// Which side of the value a [CoilInputCopy]'s action sits on.
enum CoilInputCopyAlign {
  /// After the value (the trailing side).
  end,

  /// Before the value (the leading side).
  start,
}

enum _Status { idle, copied, failed }

/// The texts a [CoilInputCopy] shows and announces, for localization.
@immutable
class CoilInputCopyLabels {
  /// Creates the labels; the defaults are English.
  const CoilInputCopyLabels({
    this.copy = 'Copy',
    this.copied = 'Copied',
    this.failed = 'Failed',
    this.copyFailed = 'Copy failed',
    this.copyToClipboard = 'Copy to clipboard',
  });

  /// The button variant's idle label, and the start of the semantic label
  /// ("Copy API key").
  final String copy;

  /// Shown and announced after a copy.
  final String copied;

  /// The button variant's label after a failed copy.
  final String failed;

  /// Announced after a failed copy.
  final String copyFailed;

  /// The semantic label without a [CoilInputCopy.label].
  final String copyToClipboard;

  @override
  bool operator ==(Object other) =>
      other is CoilInputCopyLabels &&
      other.copy == copy &&
      other.copied == copied &&
      other.failed == failed &&
      other.copyFailed == copyFailed &&
      other.copyToClipboard == copyToClipboard;

  @override
  int get hashCode =>
      Object.hash(copy, copied, failed, copyFailed, copyToClipboard);
}

/// A read-only value with a copy button: an API key, an invite link.
///
/// The whole row copies [value] on a tap, click, Enter or Space. The result
/// shows inline for 2 s on every platform, so touch users see it too: the
/// icon becomes a check (or a red × if the clipboard refused), and the
/// [CoilInputCopyVariant.button] label reads "Copied". Screen readers hear
/// the result, and iOS and Android give a light haptic.
///
/// A hovering mouse highlights the value. The value stays on one line and
/// truncates; the full text is what gets copied and announced.
class CoilInputCopy extends StatefulWidget {
  /// Creates a copy row.
  const CoilInputCopy({
    required this.value,
    super.key,
    this.icon,
    this.label,
    this.variant = CoilInputCopyVariant.icon,
    this.align = CoilInputCopyAlign.end,
    this.enabled = true,
    this.onCopied,
    this.labels = const CoilInputCopyLabels(),
    this.focusNode,
    this.autofocus = false,
    this.size,
    this.motion,
    this.style,
  });

  /// The text shown and copied.
  final String value;

  /// The copy glyph, styled by [IconTheme] (coil bundles no icons). The
  /// copied check and the failed × are drawn by the component.
  final Widget? icon;

  /// A label shown above the row, also used in the semantic label
  /// ("Copy API key").
  final String? label;

  /// Icon only, or icon plus a "Copy" label.
  final CoilInputCopyVariant variant;

  /// Which side of the value the action sits on.
  final CoilInputCopyAlign align;

  /// Whether the row can copy.
  final bool enabled;

  /// Called after the value was copied.
  final VoidCallback? onCopied;

  /// The texts shown and announced.
  final CoilInputCopyLabels labels;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Pins the row to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Overrides for this row's look.
  final CoilInputCopyStyle? style;

  /// How long a copy result shows before the row goes back to idle.
  static const resetDelay = Duration(seconds: 2);

  @override
  State<CoilInputCopy> createState() => _CoilInputCopyState();
}

class _CoilInputCopyState extends State<CoilInputCopy> {
  var _status = _Status.idle;

  /// Steps on every copy, so a repeated copy replays the swap.
  var _generation = 0;
  Timer? _reset;

  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    var status = _Status.copied;
    try {
      await Clipboard.setData(ClipboardData(text: widget.value));
    } on PlatformException {
      status = _Status.failed;
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _generation++;
    });
    _reset?.cancel();
    _reset = Timer(CoilInputCopy.resetDelay, () {
      if (mounted) setState(() => _status = _Status.idle);
    });
    final labels = widget.labels;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        status == _Status.copied ? labels.copied : labels.copyFailed,
        Directionality.of(context),
      ),
    );
    if (status == _Status.copied) {
      unawaited(CoilHaptics.play(CoilHapticEvent.copy));
      widget.onCopied?.call();
    }
  }

  String _semanticLabel() {
    final labels = widget.labels;
    return switch (_status) {
      _Status.copied => labels.copied,
      _Status.failed => labels.copyFailed,
      _Status.idle => switch (widget.label) {
        final label? => '${labels.copy} $label',
        null => labels.copyToClipboard,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilInputCopyStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilInputCopyStyle>(context)).merge(widget.style);
    final radius = style.radius!;
    final start = widget.align == CoilInputCopyAlign.start;

    Widget row = Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: _semanticLabel(),
      value: widget.value,
      child: CoilInteraction(
        onPressed: widget.enabled ? _copy : null,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        minHitTarget: sizes.minHitTarget,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final showing = _status != _Status.idle;
          final actionStates = {
            if (hovered || showing) WidgetState.hovered,
            if (_status == _Status.failed) WidgetState.error,
          };
          final value = _Value(
            text: widget.value,
            style: style.valueStyle!,
            mark: style.mark!.resolve({if (hovered) WidgetState.hovered})!,
            motion: _motion,
          );
          final action = _Action(
            status: _status,
            generation: _generation,
            variant: widget.variant,
            icon: widget.icon,
            labels: widget.labels,
            color: style.actionColor!.resolve(actionStates)!,
            weight: hovered ? CoilIconWeight.emphasis : CoilIconWeight.rest,
            textStyle: style.actionStyle!,
            iconSize: sizes.iconSize,
            gap: 6,
            motion: _motion,
          );
          final padY = sizes.controlPaddingY(sizes.body);
          return CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: BorderRadius.circular(radius),
            child: MotionBuilder<Color>(
              value: style.fill!.resolve({
                if (states.contains(WidgetState.pressed)) WidgetState.pressed,
              })!,
              motion: _motion.fade,
              converter: MotionConverter.colorRgb,
              builder: (context, fill, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                child: child,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: style.minHeight!),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sizes.controlPaddingX,
                    vertical: padY,
                  ),
                  child: Row(
                    spacing: sizes.gap,
                    children: [
                      if (start) action,
                      Expanded(child: value),
                      if (!start) action,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.label case final label?) {
      row = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          // The button's semantic label already says it.
          ExcludeSemantics(
            child: Padding(
              // Aligned with the row's content.
              padding: EdgeInsetsDirectional.only(
                start: sizes.controlPaddingX,
              ),
              child: Text(
                label,
                style: style.labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          row,
        ],
      );
    }
    return Opacity(opacity: widget.enabled ? 1 : 0.5, child: row);
  }
}

/// The value, one line, with the hover mark behind its text.
class _Value extends StatelessWidget {
  const _Value({
    required this.text,
    required this.style,
    required this.mark,
    required this.motion,
  });

  final String text;
  final TextStyle style;
  final Color mark;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: MotionBuilder<Color>(
      value: mark,
      motion: motion.fade,
      converter: MotionConverter.colorRgb,
      builder: (context, mark, child) => DecoratedBox(
        decoration: ShapeDecoration(
          color: mark,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        child: child,
      ),
      // The full value is the row's semantic value.
      child: ExcludeSemantics(
        child: Text(
          text,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

/// The copy action: an icon (and label) that swaps to the result.
class _Action extends StatelessWidget {
  const _Action({
    required this.status,
    required this.generation,
    required this.variant,
    required this.icon,
    required this.labels,
    required this.color,
    required this.weight,
    required this.textStyle,
    required this.iconSize,
    required this.gap,
    required this.motion,
  });

  final _Status status;
  final int generation;
  final CoilInputCopyVariant variant;
  final Widget? icon;
  final CoilInputCopyLabels labels;
  final Color color;
  final double weight;
  final TextStyle textStyle;
  final double iconSize;
  final double gap;
  final CoilMotion motion;

  Widget _glyph(_Status status) => switch (status) {
    _Status.idle => icon ?? const SizedBox.shrink(),
    _Status.copied => _ResultGlyph(
      glyph: _Glyph.check,
      motion: motion,
    ),
    _Status.failed => _ResultGlyph(
      glyph: _Glyph.cross,
      motion: motion,
    ),
  };

  String _text(_Status status) => switch (status) {
    _Status.idle => labels.copy,
    _Status.copied => labels.copied,
    _Status.failed => labels.failed,
  };

  Widget _content(_Status status, {required bool ghost}) {
    final glyph = ghost ? SizedBox.square(dimension: iconSize) : _glyph(status);
    if (variant == CoilInputCopyVariant.icon) return glyph;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [glyph, Text(_text(status), maxLines: 1, softWrap: false)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = ValueKey((status, status == .idle ? 0 : generation));
    final swap = MotionSwitcher(
      motion: motion.quick,
      exitMotion: motion.quickExit,
      transitionBuilder: CoilBlurFade.transition(scale: 0.8),
      debugLabel: 'CoilInputCopy.action',
      child: KeyedSubtree(
        key: key,
        child: _content(status, ghost: false),
      ),
    );
    return MotorInspectionScope(
      group: 'CoilInputCopy',
      child: ExcludeSemantics(
        child: IconTheme(
          data: IconThemeData(
            size: iconSize,
            applyTextScaling: true,
            color: color,
            weight: weight,
          ),
          child: MotionBuilder<Color>(
            value: color,
            motion: motion.fade,
            converter: MotionConverter.colorRgb,
            builder: (context, color, child) => DefaultTextStyle(
              style: textStyle.copyWith(color: color),
              child: IconTheme.merge(
                data: IconThemeData(color: color),
                child: child!,
              ),
            ),
            child: variant == CoilInputCopyVariant.icon
                ? swap
                // Every label's width is reserved, so the row never shifts
                // as "Copy" becomes "Copied".
                : Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [
                      for (final ghost in _Status.values)
                        Visibility.maintain(
                          visible: false,
                          child: _content(ghost, ghost: true),
                        ),
                      swap,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

enum _Glyph { check, cross }

/// A result glyph that draws itself in on `fade` when it appears.
class _ResultGlyph extends StatelessWidget {
  const _ResultGlyph({required this.glyph, required this.motion});

  final _Glyph glyph;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) {
    final size = CoilIconSize.of(context);
    final color = IconTheme.of(context).color!;
    return SingleMotionBuilder(
      value: 1,
      from: 0,
      motion: motion.fade,
      builder: (context, progress, _) => CustomPaint(
        size: Size.square(size),
        painter: _ResultPainter(glyph, progress.clamp(0, 1), color),
      ),
    );
  }
}

class _ResultPainter extends CustomPainter {
  _ResultPainter(this.glyph, this.progress, this.color);

  final _Glyph glyph;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = ui.Path();
    switch (glyph) {
      case _Glyph.check:
        path
          ..moveTo(5, 12.5)
          ..lineTo(9.5, 17)
          ..lineTo(19, 7.5);
      case _Glyph.cross:
        path
          ..moveTo(7, 7)
          ..lineTo(17, 17)
          ..moveTo(17, 7)
          ..lineTo(7, 17);
    }
    final drawn = ui.Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawPath(
        drawn,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ResultPainter old) =>
      old.glyph != glyph || old.progress != progress || old.color != color;
}
