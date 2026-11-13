import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input/input_group.dart';
import 'package:coil/src/components/input/input_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilInput], as Motor tracks. Use them as keys of
/// [CoilInput.motions] or [CoilThemeData.trackMotions].
final class CoilInputTrack<T extends Object> extends Track<T> {
  CoilInputTrack._(super.converter, {required String super.debugLabel});

  /// The hairline color. Default motion: `fade`.
  static final border = CoilInputTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInput.border',
  );

  /// The background color. Default motion: `fade`.
  static final fill = CoilInputTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilInput.fill',
  );
}

/// A text field: single-line, or multi-line with [CoilInput.multiline].
///
/// It uses the platform's own text editing: IME composition, selection
/// gestures and handles, the magnifier and the native edit menu.
///
/// Focus darkens the border, whether it came from a tap or the keyboard. A
/// hovering mouse adds a faint fill; touch never does. Inside a `CoilField`,
/// it takes the field's invalid state and focuses when the label is tapped.
/// Give it a field label: the placeholder is an example, not a label.
class CoilInput extends StatefulWidget {
  /// Creates a single-line input.
  const CoilInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.readOnly = false,
    this.invalid = false,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.size,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  }) : minLines = null,
       maxLines = 1;

  /// Creates a multi-line input (a textarea).
  ///
  /// It starts [minLines] tall and grows with its text up to [maxLines], then
  /// scrolls. Growth is instant. Return inserts a newline; a Return that only
  /// commits an IME composition doesn't. Slots sit on the first line, and the
  /// first line lines up with a single-line input's text.
  const CoilInput.multiline({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.leading,
    this.trailing,
    int this.minLines = 3,
    this.maxLines = 10,
    this.enabled = true,
    this.readOnly = false,
    this.invalid = false,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.size,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  }) : assert(minLines > 0, 'A multi-line input shows at least one line.'),
       assert(
         maxLines == null || maxLines >= minLines,
         'maxLines must be at least minLines.',
       ),
       obscureText = false,
       textInputAction = TextInputAction.newline,
       onSubmitted = null;

  /// The text controller; one is created if null.
  final TextEditingController? controller;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Shown, muted, while the field is empty. Usually a [Text].
  final Widget? placeholder;

  /// A widget before the text, usually a muted icon.
  final Widget? leading;

  /// A widget after the text, usually an icon or a small button.
  final Widget? trailing;

  /// The lines a multi-line input shows when empty. Null for single-line.
  final int? minLines;

  /// The lines a multi-line input grows to before it scrolls; null grows
  /// without limit. 1 for single-line.
  final int? maxLines;

  /// Whether the field accepts input and focus.
  final bool enabled;

  /// Whether the text can be selected but not changed. A read-only field
  /// doesn't show hover.
  final bool readOnly;

  /// Shows the invalid border (focus wins). A `CoilField` with an error sets
  /// it for you.
  final bool invalid;

  /// Hides the text, for passwords. Autocorrect and suggestions turn off.
  final bool obscureText;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The software keyboard type.
  final TextInputType? keyboardType;

  /// The keyboard's action button. Multi-line inputs use newline.
  final TextInputAction? textInputAction;

  /// How the software keyboard capitalizes.
  final TextCapitalization textCapitalization;

  /// Whether the platform autocorrects.
  final bool autocorrect;

  /// Whether the keyboard offers suggestions.
  final bool enableSuggestions;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints, such as [AutofillHints.email].
  final Iterable<String>? autofillHints;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's action button submits a single-line input.
  /// Never called for a Return that only commits an IME composition.
  final ValueChanged<String>? onSubmitted;

  /// Pins the field to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Observes, and can force, the hovered and focused looks.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens for this field.
  final CoilMotion? motion;

  /// Per-track motions for this field, keyed by [CoilInputTrack]s. They win
  /// over [CoilThemeData.trackMotions] and [motion].
  final Map<CoilInputTrack<Object>, Motion>? motions;

  /// Overrides for this field's look.
  final CoilInputStyle? style;

  /// A label for screen readers when there's no `CoilField` label.
  final String? semanticLabel;

  bool get _multiline => maxLines != 1;

  @override
  State<CoilInput> createState() => _CoilInputState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('controller', controller, defaultValue: null))
      ..add(IntProperty('maxLines', maxLines, defaultValue: 1));
  }
}

class _CoilInputState extends State<CoilInput> {
  FocusNode? _ownFocusNode;
  WidgetStatesController? _ownStates;

  /// The first build starts the tracks at rest instead of animating in.

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CoilInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
      _onFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _ownFocusNode?.dispose();
    _ownStates?.dispose();
    super.dispose();
  }

  void _onFocus() => _states.update(WidgetState.focused, _focusNode.hasFocus);

  void _focusFromLabel() {
    if (_focusNode.canRequestFocus) _focusNode.requestFocus();
  }

  Motion _colorMotion(CoilInputTrack<Object> track) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: CoilTheme.motionOf(context, override: widget.motion).fade,
    spatial: false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final look = CoilInputStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context)).merge(widget.style);
    final multiline = widget._multiline;
    final textStyle = look.textStyle!;
    final radius = BorderRadius.circular(
      multiline ? look.multilineRadius! : look.radius!,
    );
    final invalid =
        widget.invalid || (CoilFieldScope.maybeOf(context)?.invalid ?? false);
    final groupSlot = InputGroupSlot.maybeOf(context);
    // In an input group, the group decides which field shows hover.
    final groupHovered = groupSlot == null
        ? null
        : CoilHoverItem.isActive(context, groupSlot.index);

    Widget slot(Widget child) {
      final styled = IconTheme(
        data: IconThemeData(
          size: sizes.iconSize,
          applyTextScaling: true,
          color: look.placeholder,
          weight: CoilIconWeight.rest,
        ),
        child: DefaultTextStyle(
          style: textStyle.copyWith(color: look.placeholder),
          child: child,
        ),
      );
      // On the first line of a multi-line field.
      return multiline ? CoilLineBox(style: textStyle, child: styled) : styled;
    }

    Widget decorate(BuildContext context, Widget field) => ListenableBuilder(
      listenable: _states,
      builder: (context, child) {
        final states = _states.value;
        final focused = states.contains(WidgetState.focused);
        final hovered =
            !widget.readOnly &&
            widget.enabled &&
            (groupHovered ?? states.contains(WidgetState.hovered));
        final resolved = {
          if (focused) WidgetState.focused,
          if (hovered) WidgetState.hovered,
          if (invalid) WidgetState.error,
        };
        final border = look.border!.resolve(resolved)!;
        final fill = look.fill!.resolve(resolved)!;
        return TrackBuilder(
          initialValues: [
            CoilInputTrack.border.value(border),
            CoilInputTrack.fill.value(fill),
          ],
          animations: [
            CoilInputTrack.border([
              .to(border, motion: _colorMotion(CoilInputTrack.border)),
            ]),
            CoilInputTrack.fill([
              .to(fill, motion: _colorMotion(CoilInputTrack.fill)),
            ]),
          ],
          // A minimum height plus symmetric padding: the line box sits
          // centered and the field grows with the text scale.
          builder: (context, value, child) => Container(
            constraints: BoxConstraints(minHeight: look.minHeight!),
            decoration: ShapeDecoration(
              color: value(CoilInputTrack.fill),
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(color: value(CoilInputTrack.border)),
              ),
            ),
            child: child,
          ),
          child: child,
        );
      },
      child: Padding(
        // 1 px of each side is the border.
        padding: EdgeInsets.symmetric(
          horizontal: sizes.controlPaddingX - 1,
          vertical: sizes.controlPaddingY(sizes.field) - 1,
        ),
        child: Row(
          spacing: sizes.gap,
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (widget.leading case final leading?) slot(leading),
            Expanded(child: field),
            if (widget.trailing case final trailing?) slot(trailing),
          ],
        ),
      ),
    );

    return CoilFieldControl(
      onLabelTap: widget.enabled ? _focusFromLabel : null,
      child: Semantics(
        label: widget.semanticLabel,
        // Hover from hover-capable pointers only; the core handles taps,
        // selection, focus and the text cursor.
        child: CoilInteractionDetector(
          states: _states,
          enabled: widget.enabled,
          trackPress: false,
          child: Opacity(
            opacity: widget.enabled ? 1 : sizes.disabledOpacity,
            child: CoilTextFieldCore(
              controller: widget.controller,
              focusNode: _focusNode,
              placeholder: widget.placeholder,
              placeholderColor: look.placeholder,
              style: textStyle,
              strutStyle: StrutStyle.fromTextStyle(
                textStyle,
                forceStrutHeight: true,
              ),
              cursorColor: look.cursorColor,
              cursorWidth: look.cursorWidth!,
              selectionColor: look.selectionColor,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              obscureText: widget.obscureText,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              autocorrect: widget.autocorrect,
              enableSuggestions: widget.enableSuggestions,
              keyboardAppearance: theme.brightness,
              // Keeps the field 16 clear of the keyboard and screen edges.
              scrollPadding: const EdgeInsets.all(16),
              inputFormatters: widget.inputFormatters,
              autofillHints: widget.autofillHints,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decorationBuilder: decorate,
            ),
          ),
        ),
      ),
    );
  }
}
