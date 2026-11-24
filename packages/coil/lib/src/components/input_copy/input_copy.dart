// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

/// @docImport 'package:coil/field.dart';
library;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input_copy/input_copy_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilInputCopy], as Motor tracks.
///
/// Use these as keys of [CoilInputCopy.motions] or
/// [CoilInputCopyStyle.motions].
final class CoilInputCopyTrack<T extends Object> extends Track<T> {
  CoilInputCopyTrack._(super.converter, {required String super.debugLabel});

  /// The row's press fill.
  ///
  /// Defaults to [CoilMotion.fade].
  static final fill = CoilInputCopyTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInputCopy.fill',
  );

  /// The highlight behind the value.
  ///
  /// Defaults to [CoilMotion.fade].
  static final mark = CoilInputCopyTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInputCopy.mark',
  );

  /// The action's icon and text color.
  ///
  /// Defaults to [CoilMotion.fade].
  static final action = CoilInputCopyTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInputCopy.action',
  );

  /// The action icon's weight.
  ///
  /// Defaults to [CoilMotion.fade].
  static final weight = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.weight',
  );

  /// The swap between the copy icon and the result.
  ///
  /// Defaults to [CoilMotion.quick] in and [CoilMotion.quickExit] out; an
  /// override applies to both.
  static final swap = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.swap',
  );

  /// The width of the action's label as it goes from "Copy" to "Copied" and
  /// back.
  ///
  /// The row springs between the labels' real widths; defaults to
  /// [CoilMotion.standard].
  static final size = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.size',
  );

  /// The check or × drawing itself in.
  ///
  /// Defaults to [CoilMotion.fade].
  static final draw = CoilInputCopyTrack<double>._(
    .single,
    debugLabel: 'CoilInputCopy.draw',
  );
}

/// Visual style of the copy trigger in a [CoilInputCopy].
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

/// Display and accessibility labels for a [CoilInputCopy].
///
/// The widgets are what [CoilInputCopyVariant.button] shows, usually a [Text];
/// the `*Label` strings are for screen readers. Defaults to English.
@immutable
class CoilInputCopyLabels {
  /// Creates the labels.
  const CoilInputCopyLabels({
    this.copy = const Text('Copy'),
    this.copied = const Text('Copied'),
    this.failed = const Text('Failed'),
    this.copyLabel = 'Copy',
    this.copiedLabel = 'Copied',
    this.copyFailedLabel = 'Copy failed',
    this.copyToClipboardLabel = 'Copy to clipboard',
  });

  /// The button's label at rest.
  final Widget copy;

  /// The button's label after a copy.
  final Widget copied;

  /// The button's label after a failed copy.
  final Widget failed;

  /// The spoken name inside a [CoilField].
  final String copyLabel;

  /// Announced after a copy.
  final String copiedLabel;

  /// Announced after a failed copy.
  final String copyFailedLabel;

  /// The spoken name outside a [CoilField].
  final String copyToClipboardLabel;

  @override
  bool operator ==(Object other) =>
      other is CoilInputCopyLabels &&
      other.copy == copy &&
      other.copied == copied &&
      other.failed == failed &&
      other.copyLabel == copyLabel &&
      other.copiedLabel == copiedLabel &&
      other.copyFailedLabel == copyFailedLabel &&
      other.copyToClipboardLabel == copyToClipboardLabel;

  @override
  int get hashCode => Object.hash(
    copy,
    copied,
    failed,
    copyLabel,
    copiedLabel,
    copyFailedLabel,
    copyToClipboardLabel,
  );
}

/// A read-only value with a copy button: an API key, an invite link.
///
/// The whole row copies [value] on a tap, click, Enter or Space, and so does
/// a tap on its [CoilField] label. The result shows inline for 2 s on every
/// platform, so touch users see it too: the icon becomes a check (or a red ×
/// if the clipboard refused), and the [CoilInputCopyVariant.button] label
/// reads "Copied". Copying again while the result shows only restarts the
/// 2 s (nothing animates again); copying while it leaves brings it back
/// from where it is. Screen readers hear the result when it appears, and
/// iOS and Android give a light haptic on each copy. The behavior is
/// [CoilCopyController]'s, shared with every copy affordance.
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

  /// The copy icon.
  ///
  /// When null, shows the theme's [CoilIcons.copy], else Coil's drawn copy
  /// glyph, so the action always shows. The check and × after a copy are
  /// [CoilIcons.check] and [CoilIcons.failed] (see [CoilCopyGlyph]).
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

  /// The spoken name at rest, such as "Copy API key".
  ///
  /// Inside a [CoilField] the field's label is read with it.
  final String? semanticLabel;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Pins the row to one size step.
  ///
  /// Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this row.
  final CoilMotion? motion;

  /// Per-track motions for this row, keyed by [CoilInputCopyTrack]s.
  ///
  /// They win over the style's [CoilInputCopyStyle.motions] and [motion].
  final Map<CoilInputCopyTrack<Object>, Motion>? motions;

  /// Overrides for this row's look.
  final CoilInputCopyStyle? style;

  /// How long a copy result shows after the last copy, as DESIGN.md names it.
  ///
  /// Not configurable.
  static const resetDelay = CoilCopyController.defaultResetDelay;

  @override
  State<CoilInputCopy> createState() => _CoilInputCopyState();
}

class _CoilInputCopyState extends State<CoilInputCopy> {
  final _copy = CoilCopyController();

  @override
  void initState() {
    super.initState();
    _copy.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  Future<void> _onCopy() async {
    final labels = widget.labels;
    final status = await _copy.copy(
      widget.value,
      context: context,
      copiedLabel: labels.copiedLabel,
      failedLabel: labels.copyFailedLabel,
    );
    if (mounted && status == CoilCopyStatus.copied) widget.onCopied?.call();
  }

  String _semanticLabel(bool inField) {
    final labels = widget.labels;
    return switch (_copy.value) {
      CoilCopyStatus.copied => labels.copiedLabel,
      CoilCopyStatus.failed => labels.copyFailedLabel,
      CoilCopyStatus.idle =>
        widget.semanticLabel ??
            (inField ? labels.copyLabel : labels.copyToClipboardLabel),
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
    Motion motionFor(
      CoilInputCopyTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: widget.motions,
      styled: style.motions,
      token: token,
      spatial: spatial,
    );
    // The swap and draw run in the shared copy widgets, which resolve
    // reduced motion and the tokens; they get only what was set here.
    Motion? customOf(CoilInputCopyTrack<Object> track) =>
        widget.motions?[track] ?? style.motions?[track];
    final radius = BorderRadius.circular(style.radius!);
    final inField = CoilFieldScope.maybeOf(context) != null;
    final onCopy = widget.enabled ? _onCopy : null;

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
            final action = switch (_copy.value) {
              CoilCopyStatus.copied => style.copiedColor!,
              CoilCopyStatus.failed => style.failedColor!,
              CoilCopyStatus.idle => style.actionColor!.resolve(hover)!,
            };
            final weight = hovered
                ? CoilIconWeight.emphasis
                : CoilIconWeight.rest;
            Motion fade(CoilInputCopyTrack<Object> track) =>
                motionFor(track, motion.fade, spatial: false);

            return Opacity(
              opacity: widget.enabled ? 1 : sizes.disabledOpacity,
              child: CoilFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                child: MotorInspectionScope(
                  group: 'CoilInputCopy',
                  child: TrackBuilder(
                    initialValues: [
                      CoilInputCopyTrack.fill.value(fill),
                      CoilInputCopyTrack.mark.value(mark),
                      CoilInputCopyTrack.action.value(action),
                      CoilInputCopyTrack.weight.value(weight),
                    ],
                    animations: [
                      CoilInputCopyTrack.fill([
                        .to(fill, motion: fade(CoilInputCopyTrack.fill)),
                      ]),
                      CoilInputCopyTrack.mark([
                        .to(mark, motion: fade(CoilInputCopyTrack.mark)),
                      ]),
                      CoilInputCopyTrack.action([
                        .to(action, motion: fade(CoilInputCopyTrack.action)),
                      ]),
                      CoilInputCopyTrack.weight([
                        .to(weight, motion: fade(CoilInputCopyTrack.weight)),
                      ]),
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
                        status: _copy.value,
                        variant: widget.variant,
                        icon: widget.icon,
                        labels: widget.labels,
                        style: style,
                        color: value(CoilInputCopyTrack.action),
                        weight: value(CoilInputCopyTrack.weight),
                        motion: widget.motion,
                        sizeMotion: motionFor(
                          CoilInputCopyTrack.size,
                          motion.standard,
                        ),
                        swapMotion: motionFor(
                          CoilInputCopyTrack.swap,
                          motion.quick,
                        ),
                        swapExitMotion: motionFor(
                          CoilInputCopyTrack.swap,
                          motion.quickExit,
                        ),
                        motions: {
                          CoilCopyTrack.swap: ?customOf(
                            CoilInputCopyTrack.swap,
                          ),
                          CoilCopyTrack.draw: ?customOf(
                            CoilInputCopyTrack.draw,
                          ),
                        },
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
            vertical: sizes.controlPaddingY(style.valueStyle!),
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
    required this.variant,
    required this.icon,
    required this.labels,
    required this.style,
    required this.color,
    required this.weight,
    required this.motion,
    required this.sizeMotion,
    required this.swapMotion,
    required this.swapExitMotion,
    required this.motions,
  });

  final CoilCopyStatus status;
  final CoilInputCopyVariant variant;
  final Widget? icon;
  final CoilInputCopyLabels labels;
  final CoilInputCopyStyle style;
  final Color color;
  final double weight;
  final CoilMotion? motion;
  final Motion sizeMotion;
  final Motion swapMotion;
  final Motion swapExitMotion;
  final Map<CoilCopyTrack<Object>, Motion> motions;

  Widget _text(CoilCopyStatus status) => switch (status) {
    CoilCopyStatus.idle => labels.copy,
    CoilCopyStatus.copied => labels.copied,
    CoilCopyStatus.failed => labels.failed,
  };

  Widget _label(CoilCopyStatus status) => DefaultTextStyle.merge(
    maxLines: 1,
    softWrap: false,
    child: _text(status),
  );

  @override
  Widget build(BuildContext context) {
    // The icon swaps itself; the label cross-fades beside it. Both are
    // keyed by status alone: a copy while "Copied" shows animates nothing,
    // and one while it leaves turns it around.
    final glyph = CoilCopyGlyph(
      status: status,
      icon: icon,
      motion: motion,
      motions: motions,
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
              ? glyph
              // The label cross-fades beside the icon, and the row springs
              // from one label's width to the next one's.
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: style.actionGap!,
                  children: [
                    glyph,
                    CoilSizeSwitcher(
                      alignment: AlignmentDirectional.centerStart,
                      sizeMotion: sizeMotion,
                      fadeMotion: swapMotion,
                      fadeExitMotion: swapExitMotion,
                      contentKey: status,
                      debugLabel: 'CoilInputCopy.label',
                      child: _label(status),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
