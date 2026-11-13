// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input_copy/input_copy_style.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The animated parts of a [CoilInputCopy], as Motor tracks. Use them as
/// keys of [CoilInputCopy.motions] or [CoilThemeData.trackMotions].
final class CoilInputCopyTrack<T extends Object> extends Track<T> {
  CoilInputCopyTrack._(super.converter, {required String super.debugLabel});

  /// The row's press fill. Default motion: `fade`.
  static final fill = CoilInputCopyTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInputCopy.fill',
  );

  /// The highlight behind the value. Default motion: `fade`.
  static final mark = CoilInputCopyTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInputCopy.mark',
  );

  /// The action's icon and text color. Default motion: `fade`.
  static final action = CoilInputCopyTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInputCopy.action',
  );

  /// The action icon's weight. Default motion: `fade`.
  static final weight = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.weight',
  );

  /// The swap between the copy icon and the result. Default motion: `quick`
  /// in, `quickExit` out; an override applies to both.
  static final swap = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.swap',
  );

  /// The check or × drawing itself in. Default motion: `fade`.
  static final draw = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.draw',
  );
}

/// How a [CoilInputCopy] shows its copy action.
enum CoilInputCopyVariant {
  /// The icon alone.
  icon,

  /// The icon with a "Copy" label.
  button,
}

/// Which side of the value a [CoilInputCopy]'s action sits on.
enum CoilInputCopyAlign {
  /// After the value.
  end,

  /// Before the value.
  start,
}

/// The texts a [CoilInputCopy] shows and announces. The defaults are
/// English.
@immutable
class CoilInputCopyLabels {
  /// Creates the labels.
  const CoilInputCopyLabels({
    this.copy = 'Copy',
    this.copied = 'Copied',
    this.failed = 'Failed',
    this.copyFailed = 'Copy failed',
    this.copyToClipboard = 'Copy to clipboard',
  });

  /// The button label, and the spoken name inside a `CoilField`.
  final String copy;

  /// Shown and announced after a copy.
  final String copied;

  /// The button label after a failed copy.
  final String failed;

  /// Announced after a failed copy.
  final String copyFailed;

  /// The spoken name outside a `CoilField`.
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
/// The whole row copies [value] on a tap, click, Enter or Space, and so does
/// a tap on its `CoilField` label. The result shows inline for 2 s on every
/// platform, so touch users see it too: the icon becomes a check (or a red ×
/// if the clipboard refused), and the [CoilInputCopyVariant.button] label
/// reads "Copied". Screen readers hear the result, and iOS and Android give
/// a light haptic.
///
/// A hovering mouse highlights the value. The value stays on one line and
/// truncates; the full text is what gets copied and announced.
class CoilInputCopy extends StatefulWidget {
  /// Creates a copy row.
  const CoilInputCopy({
    required this.value,
    super.key,
    this.icon,
    this.variant = CoilInputCopyVariant.icon,
    this.align = CoilInputCopyAlign.end,
    this.enabled = true,
    this.onCopied,
    this.labels = const CoilInputCopyLabels(),
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The text shown and copied.
  final String value;

  /// The copy icon. coil bundles no icons; the check and × are drawn.
  final Widget? icon;

  /// Icon only, or icon and a "Copy" label.
  final CoilInputCopyVariant variant;

  /// Which side of the value the action sits on.
  final CoilInputCopyAlign align;

  /// Whether the row can copy.
  final bool enabled;

  /// Called after the value was copied.
  final VoidCallback? onCopied;

  /// The texts shown and announced.
  final CoilInputCopyLabels labels;

  /// The spoken name at rest, such as "Copy API key". Inside a `CoilField`
  /// the field's label is read with it.
  final String? semanticLabel;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Pins the row to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this row.
  final CoilMotion? motion;

  /// Per-track motions for this row, keyed by [CoilInputCopyTrack]s. They
  /// win over [CoilThemeData.trackMotions] and [motion].
  final Map<CoilInputCopyTrack<Object>, Motion>? motions;

  /// Overrides for this row's look.
  final CoilInputCopyStyle? style;

  /// How long a copy result shows, as DESIGN.md names it. Not configurable.
  static const resetDelay = Duration(seconds: 2);

  @override
  State<CoilInputCopy> createState() => _CoilInputCopyState();
}

enum _Status { idle, copied, failed }

// The one place InputCopy asks for a haptic, so moving to the theme's
// haptics is a one-line change.
void _playCopyHaptic() => unawaited(CoilHaptics.play(CoilHapticEvent.copy));

class _CoilInputCopyState extends State<CoilInputCopy> {
  var _status = _Status.idle;

  /// Steps on every copy, so a repeated copy replays the swap.
  var _generation = 0;
  Timer? _reset;

  /// The first build starts the tracks at rest instead of animating in.
  bool _started = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Motion _motionFor(
    CoilInputCopyTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

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
      _playCopyHaptic();
      widget.onCopied?.call();
    }
  }

  String _semanticLabel(bool inField) {
    final labels = widget.labels;
    return switch (_status) {
      _Status.copied => labels.copied,
      _Status.failed => labels.copyFailed,
      _Status.idle =>
        widget.semanticLabel ??
            (inField ? labels.copy : labels.copyToClipboard),
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
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final radius = BorderRadius.circular(style.radius!);
    final inField = CoilFieldScope.maybeOf(context) != null;
    final onCopy = widget.enabled ? _copy : null;

    return CoilFieldControl(
      onLabelTap: onCopy,
      child: Semantics(
        container: true,
        button: true,
        enabled: widget.enabled,
        label: _semanticLabel(inField),
        value: widget.value,
        child: CoilInteraction(
          onPressed: onCopy,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          minHitTarget: sizes.minHitTarget,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            final hover = {if (hovered) WidgetState.hovered};
            final fill = style.fill!.resolve({
              if (states.contains(WidgetState.pressed)) WidgetState.pressed,
            })!;
            final mark = style.mark!.resolve(hover)!;
            final action = switch (_status) {
              _Status.copied => style.copiedColor!,
              _Status.failed => style.failedColor!,
              _Status.idle => style.actionColor!.resolve(hover)!,
            };
            final weight = hovered
                ? CoilIconWeight.emphasis
                : CoilIconWeight.rest;
            final first = !_started;
            _started = true;
            Motion fade(CoilInputCopyTrack<Object> track) =>
                _motionFor(track, motion.fade, spatial: false);

            return Opacity(
              opacity: widget.enabled ? 1 : 0.5,
              child: CoilFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                child: MotorInspectionScope(
                  group: 'CoilInputCopy',
                  child: TrackBuilder(
                    animations: [
                      CoilInputCopyTrack.fill([
                        .to(fill, motion: fade(CoilInputCopyTrack.fill)),
                      ], from: first ? fill : null),
                      CoilInputCopyTrack.mark([
                        .to(mark, motion: fade(CoilInputCopyTrack.mark)),
                      ], from: first ? mark : null),
                      CoilInputCopyTrack.action([
                        .to(action, motion: fade(CoilInputCopyTrack.action)),
                      ], from: first ? action : null),
                      CoilInputCopyTrack.weight([
                        .to(weight, motion: fade(CoilInputCopyTrack.weight)),
                      ], from: first ? weight : null),
                    ],
                    builder: (context, value, _) => _Row(
                      style: style,
                      sizes: sizes,
                      fill: value(CoilInputCopyTrack.fill),
                      align: widget.align,
                      value: _Value(
                        text: widget.value,
                        style: style,
                        mark: value(CoilInputCopyTrack.mark),
                      ),
                      action: _Action(
                        status: _status,
                        generation: _generation,
                        variant: widget.variant,
                        icon: widget.icon,
                        labels: widget.labels,
                        style: style,
                        color: value(CoilInputCopyTrack.action),
                        weight: value(CoilInputCopyTrack.weight),
                        swapIn: _motionFor(
                          CoilInputCopyTrack.swap,
                          motion.quick,
                        ),
                        swapOut: _motionFor(
                          CoilInputCopyTrack.swap,
                          motion.quickExit,
                        ),
                        draw: fade(CoilInputCopyTrack.draw),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The row: its fill, padding and the value beside the action.
class _Row extends StatelessWidget {
  const _Row({
    required this.style,
    required this.sizes,
    required this.fill,
    required this.align,
    required this.value,
    required this.action,
  });

  final CoilInputCopyStyle style;
  final CoilMetrics sizes;
  final Color fill;
  final CoilInputCopyAlign align;
  final Widget value;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final start = align == CoilInputCopyAlign.start;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(style.radius!),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: style.minHeight!),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sizes.controlPaddingX,
            vertical: sizes.controlPaddingY(sizes.body),
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
    );
  }
}

/// The value, one line, on its highlight.
class _Value extends StatelessWidget {
  const _Value({required this.text, required this.style, required this.mark});

  final String text;
  final CoilInputCopyStyle style;
  final Color mark;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: mark,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(style.markRadius!),
        ),
      ),
      // The full value is the row's semantic value.
      child: ExcludeSemantics(
        child: Text(
          text,
          style: style.valueStyle,
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
    required this.style,
    required this.color,
    required this.weight,
    required this.swapIn,
    required this.swapOut,
    required this.draw,
  });

  final _Status status;
  final int generation;
  final CoilInputCopyVariant variant;
  final Widget? icon;
  final CoilInputCopyLabels labels;
  final CoilInputCopyStyle style;
  final Color color;
  final double weight;
  final Motion swapIn;
  final Motion swapOut;
  final Motion draw;

  Widget _glyph(_Status status) => switch (status) {
    _Status.idle => icon ?? const SizedBox.shrink(),
    _Status.copied => _DrawIn(glyph: CoilGlyph.check, motion: draw),
    _Status.failed => _DrawIn(glyph: CoilGlyph.cross, motion: draw),
  };

  String _text(_Status status) => switch (status) {
    _Status.idle => labels.copy,
    _Status.copied => labels.copied,
    _Status.failed => labels.failed,
  };

  Widget _content(_Status status, {bool ghost = false}) {
    final glyph = ghost
        ? SizedBox.square(dimension: style.iconSize)
        : _glyph(status);
    if (variant == CoilInputCopyVariant.icon) return glyph;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: style.actionGap!,
      children: [glyph, Text(_text(status), maxLines: 1, softWrap: false)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final swap = MotionSwitcher(
      motion: swapIn,
      exitMotion: swapOut,
      transitionBuilder: CoilBlurFade.transition(scale: 0.8),
      debugLabel: 'CoilInputCopy.swap',
      child: KeyedSubtree(
        key: ValueKey((status, status == _Status.idle ? 0 : generation)),
        child: _content(status),
      ),
    );
    return ExcludeSemantics(
      child: IconTheme(
        data: IconThemeData(
          size: style.iconSize,
          applyTextScaling: true,
          color: color,
          weight: weight,
        ),
        child: DefaultTextStyle(
          style: style.actionStyle!.copyWith(color: color),
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
    );
  }
}

/// A result glyph that draws itself in when it appears.
class _DrawIn extends StatelessWidget {
  const _DrawIn({required this.glyph, required this.motion});

  final CoilGlyph glyph;
  final Motion motion;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: 1,
    from: 0,
    motion: motion,
    builder: (context, progress, _) =>
        CoilDrawnGlyph(glyph, progress: progress),
  );
}
