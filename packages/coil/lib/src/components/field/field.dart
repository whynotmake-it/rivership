import 'dart:ui' as ui;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/field/field_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

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

  /// Replaces the alert glyph before the [error].
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
    final control = CoilFieldScope(
      invalid: _invalid,
      isRequired: widget.isRequired,
      labelTarget: _labelTarget,
      child: widget.child,
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
      description: widget.description,
      error: widget.error == null
          ? null
          : _FieldError(
              style: style,
              icon: widget.errorIcon,
              child: widget.error!,
            ),
      control: control,
    );
    return switch (widget.orientation) {
      CoilFieldOrientation.vertical => body(beside: false),
      CoilFieldOrientation.horizontal => body(beside: true),
      CoilFieldOrientation.responsive => LayoutBuilder(
        builder: (context, constraints) => body(
          beside: constraints.maxWidth >= style.responsiveBreakpoint!,
        ),
      ),
    };
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
    required this.description,
    required this.error,
    required this.control,
  });

  final CoilFieldStyle style;
  final bool beside;
  final bool invalid;
  final bool isRequired;
  final Widget? label;
  final Widget? description;
  final Widget? error;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final description = this.description == null
        ? null
        : DefaultTextStyle.merge(
            style: style.descriptionStyle,
            child: this.description!,
          );
    final Widget body;
    if (beside) {
      final text = [?label, ?description];
      body = Row(
        spacing: style.besideGap!,
        children: [
          if (text.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: style.messageGap!,
                children: text,
              ),
            ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: control,
            ),
          ),
        ],
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
          if (description != null) ...[
            SizedBox(height: style.messageGap),
            description,
          ],
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
        child: error == null
            ? body
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: style.messageGap!,
                children: [body, error!],
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
                    child: const CoilDrawnGlyph(CoilGlyph.alert),
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
