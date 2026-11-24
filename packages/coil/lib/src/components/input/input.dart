import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input/input_group.dart';
import 'package:coil/src/components/input/input_slot_layout.dart';
import 'package:coil/src/components/input/input_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilInput], as Motor tracks. Use them as keys of
/// [CoilInput.motions] or [CoilInputStyle.motions].
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
    this.leadingPlacement,
    this.trailingPlacement,
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
    this.onTap,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onEditingComplete,
    this.onTapOutside,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.undoController,
    this.contextMenuBuilder = CoilTextFieldCore.defaultContextMenuBuilder,
    this.enableInteractiveSelection = true,
    this.keyboardAppearance,
    this.restorationId,
    this.spellCheckConfiguration,
    this.smartDashesType,
    this.smartQuotesType,
    this.scrollPadding = const EdgeInsets.all(16),
    this.obscuringCharacter = '•',
    this.shortcuts = const {},
    this.size,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  }) : minLines = null,
       maxLines = 1,
       scrollController = null;

  /// Creates a multi-line input (a textarea).
  ///
  /// It starts [minLines] tall and grows with its text up to [maxLines], then
  /// scrolls. Growth is instant. Return inserts a newline; a Return that only
  /// commits an IME composition doesn't. Slots that fit a line sit on the
  /// first line, and a button sits in the bottom corner; the first line
  /// lines up with a single-line input's text.
  const CoilInput.multiline({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.leading,
    this.trailing,
    this.leadingPlacement,
    this.trailingPlacement,
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
    this.onTap,
    this.onSubmitted,
    this.textInputAction = TextInputAction.newline,
    this.scrollController,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onEditingComplete,
    this.onTapOutside,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.undoController,
    this.contextMenuBuilder = CoilTextFieldCore.defaultContextMenuBuilder,
    this.enableInteractiveSelection = true,
    this.keyboardAppearance,
    this.restorationId,
    this.spellCheckConfiguration,
    this.smartDashesType,
    this.smartQuotesType,
    this.scrollPadding = const EdgeInsets.all(16),
    this.shortcuts = const {},
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
       obscuringCharacter = '•';

  /// The text controller; one is created if null.
  final TextEditingController? controller;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Shown, muted, while the field is empty. Usually a [Text].
  final Widget? placeholder;

  /// A widget before the text, usually a muted icon.
  ///
  /// See [trailing] for how a slot is placed.
  final Widget? leading;

  /// A widget after the text: an icon, a unit such as "EUR", or a button.
  ///
  /// A slot that fits a line of text sits beside it. A taller one, such as
  /// a `CoilButton`, goes into the field's padding instead, centered and as
  /// far from the side as from the top and bottom, so the field keeps its
  /// height: a compact button sits 4 in from a regular field's edges. The
  /// field grows only when the slot doesn't fit. A `CoilButton` here is
  /// compact by default, with its corners concentric with the field's. The
  /// slot is measured in the same layout pass as the text, so the first
  /// frame is right. [trailingPlacement] overrides the choice.
  final Widget? trailing;

  /// Where [leading] goes. Null is [CoilInputSlotPlacement.auto].
  final CoilInputSlotPlacement? leadingPlacement;

  /// Where [trailing] goes. Null is [CoilInputSlotPlacement.auto]:
  /// beside the text if it fits a line, into the padding if it's taller.
  final CoilInputSlotPlacement? trailingPlacement;

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

  /// The keyboard's action button. A multi-line input defaults to newline.
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

  /// Called when the keyboard's action button submits the input. A
  /// multi-line input only submits if [textInputAction] isn't newline. Never
  /// called for a Return that only commits an IME composition.
  final ValueChanged<String>? onSubmitted;

  /// Called when a pointer or a finger taps the input, never when focus
  /// arrives some other way (Tab); see [CoilTextFieldCore.onTap].
  final VoidCallback? onTap;

  /// The most characters the input accepts; null for no limit. See
  /// `TextField.maxLength`.
  final int? maxLength;

  /// How [maxLength] is enforced. Defaults to the platform's. See
  /// `TextField.maxLengthEnforcement`.
  final MaxLengthEnforcement? maxLengthEnforcement;

  /// Called when the user finishes editing, before [onSubmitted]. See
  /// `TextField.onEditingComplete`.
  final VoidCallback? onEditingComplete;

  /// Called when a pointer taps outside the input. Null keeps the default.
  /// See `TextField.onTapOutside`.
  final TapRegionCallback? onTapOutside;

  /// How the text, and the placeholder, align horizontally. See
  /// `TextField.textAlign`.
  final TextAlign textAlign;

  /// The text's direction. Defaults to the ambient [Directionality]. See
  /// `TextField.textDirection`.
  final TextDirection? textDirection;

  /// The undo history controller; one is created if null. See
  /// `TextField.undoController`.
  final UndoHistoryController? undoController;

  /// The character shown for each obscured character. See
  /// `TextField.obscuringCharacter`.
  final String obscuringCharacter;

  /// Scrolls a multi-line input's text; null for single-line. See
  /// `TextField.scrollController`.
  final ScrollController? scrollController;

  /// Builds the selection toolbar. Null shows no menu. See
  /// `TextField.contextMenuBuilder`.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// Whether the text can be selected and the toolbar shown. See
  /// `TextField.enableInteractiveSelection`.
  final bool enableInteractiveSelection;

  /// The software keyboard's brightness. Defaults to the theme's. See
  /// `TextField.keyboardAppearance`.
  final Brightness? keyboardAppearance;

  /// The id the input saves its state under for restoration. See
  /// `TextField.restorationId`.
  final String? restorationId;

  /// How spell check runs and shows its results. See
  /// `TextField.spellCheckConfiguration`.
  final SpellCheckConfiguration? spellCheckConfiguration;

  /// Whether the keyboard replaces dashes with typographic ones. See
  /// `TextField.smartDashesType`.
  final SmartDashesType? smartDashesType;

  /// Whether the keyboard replaces quotes with typographic ones. See
  /// `TextField.smartQuotesType`.
  final SmartQuotesType? smartQuotesType;

  /// The space kept between the input and the screen edges (and the software
  /// keyboard) when it scrolls itself into view. See
  /// `TextField.scrollPadding`.
  final EdgeInsets scrollPadding;

  /// Keys mapped to intents for the field's owner, such as arrows that move
  /// a list's active row. They are off while an IME composes, so Enter
  /// commits the composition first.
  final Map<ShortcutActivator, Intent> shortcuts;

  /// Pins the field to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Observes, and can force, the hovered and focused looks.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens for this field.
  final CoilMotion? motion;

  /// Per-track motions for this field, keyed by [CoilInputTrack]s. They win
  /// over the style's [CoilInputStyle.motions] and [motion].
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

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final look = CoilInputStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context)).merge(widget.style);
    final fade = CoilTheme.motionOf(context, override: widget.motion).fade;
    Motion colorMotion(CoilInputTrack<Object> track) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: widget.motions,
      styled: look.motions,
      token: fade,
      spatial: false,
    );
    final multiline = widget._multiline;
    final textStyle = look.textStyle!;
    final corner = multiline ? look.multilineRadius! : look.radius!;
    final radius = BorderRadius.circular(corner);
    final invalid =
        widget.invalid || (CoilFieldScope.maybeOf(context)?.invalid ?? false);
    final groupSlot = InputGroupSlot.maybeOf(context);
    // In an input group, the group decides which field shows hover.
    final groupHovered = groupSlot == null
        ? null
        : CoilHoverItem.isActive(context, groupSlot.index);

    Widget slot(Widget child, CoilInputSlotPlacement? placement) {
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
      // A slot forced inline keeps a control's own size and corners.
      if (placement == CoilInputSlotPlacement.inline) return styled;
      return CoilInputSlotScope(
        size: CoilSize.compact,
        radii: theme.shape.radii(sizes.tier),
        fieldRadius: corner,
        fieldHeight: look.minHeight!,
        minInset: look.slotInset!,
        child: styled,
      );
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
              .to(border, motion: colorMotion(CoilInputTrack.border)),
            ]),
            CoilInputTrack.fill([
              .to(fill, motion: colorMotion(CoilInputTrack.fill)),
            ]),
          ],
          // A minimum height plus symmetric padding: the line box sits
          // centered and the field grows with the text scale.
          builder: (context, value, child) => Container(
            constraints: BoxConstraints(minHeight: look.minHeight!),
            decoration: CoilRelief.decorate(
              ShapeDecoration(
                color: value(CoilInputTrack.fill),
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(color: value(CoilInputTrack.border)),
                ),
              ),
              // A field is a well under a plastic theme.
              CoilTheme.reliefOf(
                context,
                CoilReliefRole.field,
                override: look.plasticity,
                hover: hovered ? 1 : 0,
                enabled: widget.enabled,
              ),
            ),
            child: child,
          ),
          child: child,
        );
      },
      // Slots are measured and placed with the text in one layout pass.
      child: InputSlotLayout(
        // It sits inside the 1 px border, so every edge measure loses 1.
        paddingX: sizes.controlPaddingX - 1,
        paddingY: sizes.controlPaddingY(textStyle) - 1,
        gap: sizes.gap,
        minHeight: look.minHeight! - 2,
        minInset: look.slotInset! - 1,
        minHitTarget: sizes.minHitTarget,
        lines: multiline ? InputSlotLines.multi : InputSlotLines.single,
        leadingPlacement: widget.leadingPlacement ?? .auto,
        trailingPlacement: widget.trailingPlacement ?? .auto,
        line: CoilLineBox(style: textStyle, child: const SizedBox.shrink()),
        leading: switch (widget.leading) {
          final leading? => slot(leading, widget.leadingPlacement),
          null => null,
        },
        field: field,
        trailing: switch (widget.trailing) {
          final trailing? => slot(trailing, widget.trailingPlacement),
          null => null,
        },
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
              keyboardAppearance: widget.keyboardAppearance ?? theme.brightness,
              scrollPadding: widget.scrollPadding,
              maxLength: widget.maxLength,
              maxLengthEnforcement: widget.maxLengthEnforcement,
              onEditingComplete: widget.onEditingComplete,
              onTap: widget.onTap,
              onTapOutside: widget.onTapOutside,
              textAlign: widget.textAlign,
              textDirection: widget.textDirection,
              undoController: widget.undoController,
              obscuringCharacter: widget.obscuringCharacter,
              scrollController: widget.scrollController,
              contextMenuBuilder: widget.contextMenuBuilder,
              enableInteractiveSelection: widget.enableInteractiveSelection,
              restorationId: widget.restorationId,
              spellCheckConfiguration: widget.spellCheckConfiguration,
              smartDashesType: widget.smartDashesType,
              smartQuotesType: widget.smartQuotesType,
              inputFormatters: widget.inputFormatters,
              autofillHints: widget.autofillHints,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              shortcuts: widget.shortcuts,
              decorationBuilder: decorate,
            ),
          ),
        ),
      ),
    );
  }
}
