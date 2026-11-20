import 'dart:ui' as ui;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/field/field_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilField], as Motor tracks. Use them as keys of
/// [CoilField.motions] or [CoilFieldStyle.motions].
final class CoilFieldTrack<T extends Object> extends Track<T> {
  CoilFieldTrack._(super.converter, {required String super.debugLabel});

  /// The room of the description and the error, and an error that changes
  /// size: the field grows and shrinks to fit them, gap included. Default
  /// motion: `standard` growing, `standardExit` shrinking; the messages
  /// fade on `fade` / `fadeExit`.
  static final message = CoilFieldTrack<double>._(
    .single,
    debugLabel: 'CoilField.message',
  );
}

/// Where a [CoilField] puts its label.
enum CoilFieldOrientation {
  /// The label above the control, messages below.
  vertical,

  /// The label and description at the start, the control at the end.
  horizontal,

  /// Vertical in narrow space, horizontal from the style's
  /// `responsiveBreakpoint` (448 by default).
  responsive,
}

/// A form field: a label, one control, a description and an error.
///
/// Screen readers hear all four together when they reach the control, along
/// with "required" ([isRequired]) and "invalid" (while there is an [error]).
/// A new error is announced. A tap on the label focuses or toggles the
/// control. An error also turns the label red and gives the control its
/// invalid look.
///
/// Put one control in a field. For a group of controls, use `CoilFieldSet`.
///
/// ```dart
/// CoilField(
///   label: Text('Email'),
///   description: Text('We only use it for receipts.'),
///   error: emailError == null ? null : Text(emailError),
///   isRequired: true,
///   child: CoilInput(keyboardType: TextInputType.emailAddress),
/// )
/// ```
class CoilField extends StatefulWidget {
  /// Creates a field.
  const CoilField({
    required this.child,
    super.key,
    this.label,
    this.description,
    this.error,
    this.errorIcon,
    this.isRequired = false,
    this.invalid = false,
    this.orientation = CoilFieldOrientation.vertical,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The control.
  final Widget child;

  /// Names the control. Usually a [Text].
  final Widget? label;

  /// One sentence of help under the control. Usually a [Text].
  final Widget? description;

  /// What to fix, under the control. The field is invalid while it's set.
  final Widget? error;

  /// Replaces the alert before the [error]: the theme's [CoilIcons.alert],
  /// or coil's drawn one.
  final Widget? errorIcon;

  /// Marks the field required: a muted `*` after the label, and "required"
  /// for screen readers.
  final bool isRequired;

  /// Marks the field invalid without an [error] message.
  final bool invalid;

  /// Where the label sits.
  final CoilFieldOrientation orientation;

  /// Pins the field's text to one size step. Null follows
  /// [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this field.
  final CoilMotion? motion;

  /// Per-track motions for this field, keyed by [CoilFieldTrack]s. They win
  /// over the style's [CoilFieldStyle.motions] and [motion]'s tokens.
  final Map<CoilFieldTrack<Object>, Motion>? motions;

  /// Overrides for this field's look.
  final CoilFieldStyle? style;

  @override
  State<CoilField> createState() => _CoilFieldState();
}

class _CoilFieldState extends State<CoilField> {
  final _labelTarget = CoilFieldLabelTarget();

  bool get _invalid => widget.invalid || widget.error != null;

  @override
  Widget build(BuildContext context) {
    final style = CoilFieldStyle.resolve(
      context,
      size: widget.size,
      style: widget.style,
    );
    Widget body({required bool beside}) => _FieldBody(
      style: style,
      beside: beside,
      invalid: _invalid,
      isRequired: widget.isRequired,
      label: widget.label == null
          ? null
          : _FieldLabel(
              style: style,
              beside: beside,
              invalid: _invalid,
              isRequired: widget.isRequired,
              motion: widget.motion,
              onTap: _labelTarget.activate,
              child: widget.label!,
            ),
      motion: widget.motion,
      motions: widget.motions,
      description: widget.description,
      error: widget.error == null
          ? null
          : _FieldError(
              style: style,
              icon: widget.errorIcon,
              child: widget.error!,
            ),
      errorKey: CoilSizeSwitcher.contentKeyOf(widget.error),
      control: widget.child,
    );
    return CoilFieldScope(
      invalid: _invalid,
      isRequired: widget.isRequired,
      labelTarget: _labelTarget,
      child: switch (widget.orientation) {
        CoilFieldOrientation.vertical => body(beside: false),
        CoilFieldOrientation.horizontal => body(beside: true),
        CoilFieldOrientation.responsive => LayoutBuilder(
          builder: (context, constraints) =>
              body(beside: constraints.maxWidth >= style.responsiveBreakpoint!),
        ),
      },
    );
  }
}

/// Lays out the parts and merges them into one semantics node.
class _FieldBody extends StatelessWidget {
  const _FieldBody({
    required this.style,
    required this.beside,
    required this.invalid,
    required this.isRequired,
    required this.label,
    required this.motion,
    required this.motions,
    required this.description,
    required this.error,
    required this.errorKey,
    required this.control,
  });

  final CoilFieldStyle style;
  final bool beside;
  final bool invalid;
  final bool isRequired;
  final Widget? label;
  final CoilMotion? motion;
  final Map<CoilFieldTrack<Object>, Motion>? motions;
  final Widget? description;
  final Widget? error;

  /// What the error says, so a new message cross-fades.
  final Object? errorKey;
  final Widget control;

  /// A description or an error: a slot that owns its [gap], so the field
  /// grows by the gap and the message together, and a size spring for a
  /// message that changes.
  Widget _message(
    BuildContext context,
    Widget? child, {
    required double gap,
    Object? key,
  }) {
    final tokens = CoilTheme.motionOf(context, override: motion);
    Motion track(Motion token) => CoilTheme.trackMotionOf(
      context,
      CoilFieldTrack.message,
      instance: motions,
      styled: style.motions,
      token: token,
    );
    return CoilPresentSlot(
      gap: gap,
      motion: motion,
      presenceMotion: track(tokens.standard),
      presenceExitMotion: track(tokens.standardExit),
      child: child == null
          ? null
          : CoilSizeSwitcher(
              sizeMotion: track(tokens.standard),
              motion: motion,
              fadeWithGrowth: false,
              contentKey: key ?? CoilSizeSwitcher.contentKeyOf(child),
              child: child,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = this.description == null
        ? null
        : DefaultTextStyle.merge(
            style: style.descriptionStyle,
            child: this.description!,
          );
    // The slots are always there, in the same places, so a message coming
    // or going never moves the control in the tree.
    final descriptionSlot = _message(
      context,
      description,
      // Beside, without a label, there is nothing to separate from.
      gap: beside && label == null ? 0 : style.messageGap!,
      key: CoilSizeSwitcher.contentKeyOf(this.description),
    );
    final Widget body;
    if (beside) {
      final text = label != null || description != null;
      // Beside, the row is one target for a toggle (a switch, a checkbox).
      body = CoilFieldRow(
        child: Row(
          spacing: style.besideGap!,
          children: [
            if (text)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [label ?? const SizedBox.shrink(), descriptionSlot],
                ),
              ),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: control,
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label case final label?) ...[
            Align(alignment: AlignmentDirectional.centerStart, child: label),
            SizedBox(height: style.labelGap),
          ],
          control,
          descriptionSlot,
        ],
      );
    }
    // One node: the label, control, description and error are announced
    // together, with the field's required and invalid flags.
    return MergeSemantics(
      child: Semantics(
        isRequired: isRequired ? true : null,
        validationResult: invalid
            ? ui.SemanticsValidationResult.invalid
            : ui.SemanticsValidationResult.none,
        liveRegion: error != null ? true : null,
        // Always the same shape: an error appearing or going must not move
        // the control in the tree, or it would lose its focus and state.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            body,
            _message(context, error, gap: style.messageGap!, key: errorKey),
          ],
        ),
      ),
    );
  }
}

/// The label: tappable, colored by placement and validity, with the
/// required marker.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.style,
    required this.beside,
    required this.invalid,
    required this.isRequired,
    required this.motion,
    required this.onTap,
    required this.child,
  });

  final CoilFieldStyle style;
  final bool beside;
  final bool invalid;
  final bool isRequired;
  final CoilMotion? motion;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = invalid
        ? style.errorStyle!.color!
        : beside
        ? style.besideLabelColor!
        : style.labelColor!;
    return GestureDetector(
      onTap: onTap,
      // The control carries the field's actions in semantics.
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      child: MotionBuilder<Color>(
        value: color,
        motion: CoilTheme.motionOf(context, override: motion).fade,
        converter: MotionConverter.colorRgb,
        builder: (context, color, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: style.requiredGap!,
          children: [
            Flexible(
              child: DefaultTextStyle(
                style: style.labelStyle!.copyWith(color: color),
                child: child,
              ),
            ),
            if (isRequired)
              // Screen readers hear "required" from the field's flag.
              ExcludeSemantics(
                child: Text(
                  '*',
                  style: style.labelStyle!.copyWith(
                    color: style.requiredColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The error: an alert glyph on the first line, then the message.
class _FieldError extends StatelessWidget {
  const _FieldError({
    required this.style,
    required this.icon,
    required this.child,
  });

  final CoilFieldStyle style;
  final Widget? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = style.errorStyle!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: style.errorIconGap!,
      children: [
        CoilLineBox(
          style: text,
          child: IconTheme(
            data: IconThemeData(
              size: style.errorIconSize,
              color: text.color,
              applyTextScaling: true,
              weight: CoilIconWeight.rest,
            ),
            child: ExcludeSemantics(
              child:
                  icon ??
                  IconTheme.merge(
                    data: const IconThemeData(weight: CoilIconWeight.emphasis),
                    child: const CoilIcon(CoilIconRole.alert),
                  ),
            ),
          ),
        ),
        Flexible(
          child: DefaultTextStyle(style: text, child: child),
        ),
      ],
    );
  }
}
