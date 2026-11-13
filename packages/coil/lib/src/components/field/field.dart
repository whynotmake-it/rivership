import 'dart:ui' as ui;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/field/field_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How a [CoilField] places its label relative to its control.
enum CoilFieldOrientation {
  /// The label above the control, the messages below.
  vertical,

  /// The label (and description) at the start, the control at the end.
  horizontal,

  /// Vertical below [CoilField.responsiveBreakpoint] of width, horizontal
  /// from there.
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
/// Put one control in a field. For a group of controls, use [CoilFieldSet].
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

  /// The width from which a [CoilFieldOrientation.responsive] field lays
  /// out horizontally.
  static const double responsiveBreakpoint = 448;

  /// The control.
  final Widget child;

  /// Names the control. Usually a [Text].
  final Widget? label;

  /// One sentence of help under the control. Usually a [Text].
  final Widget? description;

  /// What to fix, under the control; marks the field invalid while set.
  /// Usually a [Text] that says what to do.
  final Widget? error;

  /// Replaces the drawn alert glyph before the [error].
  final Widget? errorIcon;

  /// Marks the field required: a muted `*` after the label, and the
  /// required flag in semantics.
  final bool isRequired;

  /// Marks the field invalid without an [error] message.
  final bool invalid;

  /// Where the label sits.
  final CoilFieldOrientation orientation;

  /// Pins the field's text to one size step. Null follows
  /// [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this instance.
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
    final style = _resolveStyle(context, widget.size, widget.style);
    final control = CoilFieldScope(
      invalid: _invalid,
      isRequired: widget.isRequired,
      labelTarget: _labelTarget,
      child: widget.child,
    );
    Widget build({required bool beside}) =>
        _layout(context, style, beside: beside).withControl(control);
    return switch (widget.orientation) {
      CoilFieldOrientation.vertical => build(beside: false),
      CoilFieldOrientation.horizontal => build(beside: true),
      CoilFieldOrientation.responsive => LayoutBuilder(
        builder: (context, constraints) => build(
          beside: constraints.maxWidth >= CoilField.responsiveBreakpoint,
        ),
      ),
    };
  }

  _FieldLayout _layout(
    BuildContext context,
    CoilFieldStyle style, {
    required bool beside,
  }) => _FieldLayout(
    label: widget.label == null ? null : _label(context, style, beside),
    description: widget.description == null
        ? null
        : DefaultTextStyle.merge(
            style: style.descriptionStyle,
            child: widget.description!,
          ),
    error: widget.error == null
        ? null
        : _FieldError(
            style: style,
            icon: widget.errorIcon,
            child: widget.error!,
          ),
    style: style,
    beside: beside,
    invalid: _invalid,
    isRequired: widget.isRequired,
  );

  Widget _label(BuildContext context, CoilFieldStyle style, bool beside) {
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final color = style.labelColor!.resolve({
      if (_invalid) WidgetState.error,
      if (beside) WidgetState.selected,
    })!;
    return GestureDetector(
      onTap: _labelTarget.activate,
      // The control carries the field's actions in semantics.
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      child: MotionBuilder<Color>(
        value: color,
        motion: motion.fade,
        converter: MotionConverter.colorRgb,
        builder: (context, color, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: DefaultTextStyle(
                style: style.labelStyle!.copyWith(color: color),
                child: widget.label!,
              ),
            ),
            if (widget.isRequired)
              // The required flag says it in semantics.
              ExcludeSemantics(
                child: Text(
                  ' *',
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

CoilFieldStyle _resolveStyle(
  BuildContext context,
  CoilSize? size,
  CoilFieldStyle? style,
) {
  final theme = CoilTheme.of(context);
  final metrics = CoilTheme.metricsOf(context, size: size);
  return CoilFieldStyle.fallback(
    theme,
    metrics,
  ).merge(CoilTheme.styleOf<CoilFieldStyle>(context)).merge(style);
}

class _FieldLayout {
  const _FieldLayout({
    required this.label,
    required this.description,
    required this.error,
    required this.style,
    required this.beside,
    required this.invalid,
    required this.isRequired,
  });

  final Widget? label;
  final Widget? description;
  final Widget? error;
  final CoilFieldStyle style;
  final bool beside;
  final bool invalid;
  final bool isRequired;

  Widget withControl(Widget control) {
    final messageGap = style.messageGap!;
    final Widget body;
    if (beside) {
      final text = [?label, ?description];
      body = Row(
        spacing: 12,
        children: [
          if (text.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: messageGap,
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
          if (description case final description?) ...[
            SizedBox(height: messageGap),
            description,
          ],
        ],
      );
    }
    final error = this.error;
    // One node: label, control, description and error are announced
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
                spacing: messageGap,
                children: [body, error],
              ),
      ),
    );
  }
}

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
    final color = text.color!;
    // The glyph sits in a box one line tall, so it centers on the first
    // line however the message wraps.
    final line =
        MediaQuery.textScalerOf(context).scale(text.fontSize!) * text.height!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: line),
          child: Center(
            widthFactor: 1,
            child: IconTheme(
              data: IconThemeData(
                size: style.errorIconSize,
                color: color,
                applyTextScaling: true,
                weight: CoilIconWeight.rest,
              ),
              child: ExcludeSemantics(child: icon ?? const _AlertGlyph()),
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

/// A circled exclamation mark on the 24-unit grid, stroke 2, round caps.
class _AlertGlyph extends StatelessWidget {
  const _AlertGlyph();

  @override
  Widget build(BuildContext context) {
    final size = CoilIconSize.of(context, fallback: 14);
    return CustomPaint(
      size: Size.square(size),
      painter: _AlertPainter(IconTheme.of(context).color!),
    );
  }
}

class _AlertPainter extends CustomPainter {
  _AlertPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawCircle(const Offset(12, 12), 10, paint)
      ..drawLine(const Offset(12, 8), const Offset(12, 12), paint)
      ..drawLine(const Offset(12, 16), const Offset(12.01, 16), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_AlertPainter old) => old.color != color;
}

/// Related fields under one heading (the [legend]), such as an address
/// block or a group of checkboxes. Screen readers read the legend first.
class CoilFieldSet extends StatelessWidget {
  /// Creates a field set.
  const CoilFieldSet({
    required this.children,
    super.key,
    this.legend,
    this.description,
    this.size,
    this.style,
  });

  /// The set's title. Usually a [Text].
  final Widget? legend;

  /// One sentence under the legend.
  final Widget? description;

  /// The fields.
  final List<Widget> children;

  /// Pins the set's text to one size step.
  final CoilSize? size;

  /// Overrides for the look.
  final CoilFieldStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context, size, this.style);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (legend case final legend?) ...[
            Semantics(
              header: true,
              child: DefaultTextStyle(style: style.legendStyle!, child: legend),
            ),
            const SizedBox(height: 4),
          ],
          if (description case final description?) ...[
            DefaultTextStyle(
              style: style.descriptionStyle!,
              child: description,
            ),
            SizedBox(height: style.fieldGap! - 4),
          ] else if (legend != null)
            SizedBox(height: style.fieldGap! - 4),
          CoilFieldGroup(size: size, style: this.style, children: children),
        ],
      ),
    );
  }
}

/// Fields stacked 12 apart (16 on touch).
class CoilFieldGroup extends StatelessWidget {
  /// Creates a field group.
  const CoilFieldGroup({
    required this.children,
    super.key,
    this.size,
    this.style,
  });

  /// The fields (and separators).
  final List<Widget> children;

  /// Pins the group's spacing to one size step.
  final CoilSize? size;

  /// Overrides for the look.
  final CoilFieldStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context, size, this.style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: style.fieldGap!,
      children: children,
    );
  }
}

/// A hairline between groups of fields, 20 high, with an optional centered
/// caption ("or").
class CoilFieldSeparator extends StatelessWidget {
  /// Creates a separator.
  const CoilFieldSeparator({super.key, this.label, this.size, this.style});

  /// A short caption in the middle of the line. Usually a [Text].
  final Widget? label;

  /// Pins the caption to one size step.
  final CoilSize? size;

  /// Overrides for the look.
  final CoilFieldStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context, size, this.style);
    final line = SizedBox(
      height: 1,
      child: ColoredBox(color: style.separatorColor!),
    );
    final label = this.label;
    // Flutter has no separator role; only the caption is announced.
    return Semantics(
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: label == null
            ? Center(child: line)
            : Row(
                spacing: 8,
                children: [
                  Expanded(child: line),
                  DefaultTextStyle(
                    style: style.separatorLabelStyle!,
                    child: label,
                  ),
                  Expanded(child: line),
                ],
              ),
      ),
    );
  }
}
