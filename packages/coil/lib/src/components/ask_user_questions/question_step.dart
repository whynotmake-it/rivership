import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/ask_user_questions/ask_user_questions_style.dart';
import 'package:coil/src/components/ask_user_questions/question.dart';
import 'package:coil/src/components/ask_user_questions/question_row.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The motions a step animates with, resolved by the card.
@immutable
class QuestionStepMotions {
  /// Bundles the motions.
  const QuestionStepMotions({
    required this.tokens,
    required this.selection,
    required this.ring,
    required this.row,
  });

  /// The card's motion tokens, for the hover highlight.
  final CoilMotion tokens;

  /// Merged selection blocks.
  final Motion selection;

  /// The focus ring travelling between rows.
  final Motion ring;

  /// What each row animates with.
  final QuestionRowMotions row;
}

/// One question: its title, then its option rows (with the "other" field)
/// or its free-text field.
///
/// The rows share one hover highlight, one focus ring and merged selection
/// blocks, and are one tab stop with Up and Down between them. The "other"
/// field is its own tab stop; Up and Down in it go back to the rows.
class QuestionStep<T> extends StatefulWidget {
  /// Creates a step.
  const QuestionStep({
    required this.question,
    required this.answer,
    required this.showKeys,
    required this.look,
    required this.motions,
    required this.onPick,
    required this.onToggle,
    required this.onTextChanged,
    required this.onSubmitText,
    required this.freeTextPlaceholder,
    super.key,
    this.error,
    this.size,
  });

  /// The question.
  final CoilQuestion<T> question;

  /// Its answer so far.
  final CoilAnswer<T> answer;

  /// Whether number keys show (pointer tier).
  final bool showKeys;

  /// The resolved style.
  final CoilAskUserQuestionsStyle look;

  /// The motions.
  final QuestionStepMotions motions;

  /// Picks an option of a single-choice question.
  final ValueChanged<T> onPick;

  /// Toggles an option of a multiple-choice question.
  final ValueChanged<T> onToggle;

  /// The typed answer changed.
  final ValueChanged<String> onTextChanged;

  /// Enter, or the keyboard's action button, in a text field.
  final VoidCallback onSubmitText;

  /// The free-text field's placeholder when the question has none.
  final Widget freeTextPlaceholder;

  /// A free-text validation message, shown as the field's invalid state.
  final Widget? error;

  /// Pins the step to one size step.
  final CoilSize? size;

  @override
  State<QuestionStep<T>> createState() => QuestionStepState<T>();
}

/// The state of a [QuestionStep]; the card moves focus into it.
class QuestionStepState<T> extends State<QuestionStep<T>> {
  final _rows = <FocusNode>[];
  final _states = <WidgetStatesController>[];
  final _field = FocusNode(debugLabel: 'CoilAskUserQuestions field');
  late final _text = TextEditingController(text: widget.answer.text);
  int? _focusVisible;

  CoilQuestion<T> get _question => widget.question;
  bool get _hasOther =>
      _question.kind != CoilQuestionKind.freeText &&
      _question.otherPlaceholder != null;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onFieldFocus);
    _resize();
  }

  @override
  void didUpdateWidget(QuestionStep<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resize();
    // An answer changed from outside (a pick clearing the typed answer,
    // or the app's controller) shows in the field.
    if (widget.answer.text != _text.text) _text.text = widget.answer.text;
  }

  void _resize() {
    final count = _question.options.length;
    while (_rows.length < count) {
      final i = _rows.length;
      _rows.add(FocusNode(debugLabel: 'CoilAskUserQuestions row $i'));
      final states = WidgetStatesController();
      states.addListener(() => _onStates(i, states.value));
      _states.add(states);
    }
    while (_rows.length > count) {
      _rows.removeLast().dispose();
      _states.removeLast().dispose();
    }
  }

  void _onStates(int index, Set<WidgetState> states) {
    final focused = states.contains(WidgetState.focused);
    if (focused && _focusVisible != index) {
      setState(() => _focusVisible = index);
    } else if (!focused && _focusVisible == index) {
      setState(() => _focusVisible = null);
    }
  }

  void _onFieldFocus() => setState(() {});

  @override
  void dispose() {
    for (final node in _rows) {
      node.dispose();
    }
    for (final states in _states) {
      states.dispose();
    }
    _field
      ..removeListener(_onFieldFocus)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  /// The row Tab lands on: the first picked one, else the first.
  int get _tabStop {
    final i = _question.options.indexWhere(
      (o) => widget.answer.values.contains(o.value),
    );
    return i < 0 ? 0 : i;
  }

  /// Moves focus to where this step starts: the free-text field, else the
  /// rows' tab stop.
  void focusEntry() {
    if (_question.kind == CoilQuestionKind.freeText || _rows.isEmpty) {
      _field.requestFocus();
    } else {
      _rows[_tabStop].requestFocus();
    }
  }

  /// Moves focus into the "other" field, if there is one.
  void focusOther() {
    if (_hasOther) _field.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final look = widget.look;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.controlPaddingX),
          child: Semantics(
            container: true,
            header: true,
            child: DefaultTextStyle(
              style: look.titleStyle!,
              child: _question.title,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (_question.kind == CoilQuestionKind.freeText) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _freeText(metrics),
          ),
          if (widget.error case final error?)
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.controlPaddingX,
                metrics.tier == CoilTier.touch ? 6 : 4,
                metrics.controlPaddingX,
                0,
              ),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: DefaultTextStyle(style: look.errorStyle!, child: error),
              ),
            ),
        ] else
          _options(context, metrics),
      ],
    );
  }

  Widget _freeText(CoilMetrics metrics) {
    final placeholder = _question.placeholder ?? widget.freeTextPlaceholder;
    final pointer = metrics.tier == CoilTier.pointer;
    if (_question.lines == 1) {
      return CoilInput(
        controller: _text,
        focusNode: _field,
        placeholder: placeholder,
        invalid: widget.error != null,
        size: widget.size,
        textInputAction: TextInputAction.done,
        semanticLabel: _question.semanticLabel,
        onChanged: widget.onTextChanged,
        onSubmitted: (_) => widget.onSubmitText(),
      );
    }
    return CoilInput.multiline(
      controller: _text,
      focusNode: _field,
      placeholder: placeholder,
      minLines: _question.lines,
      maxLines: _question.lines < 10 ? 10 : _question.lines,
      invalid: widget.error != null,
      size: widget.size,
      semanticLabel: _question.semanticLabel,
      onChanged: widget.onTextChanged,
      // With a hardware keyboard, Enter answers and Shift+Enter is a new
      // line; on touch, Return is a new line and Continue answers (as in
      // CoilInputMessage).
      shortcuts: {
        if (pointer)
          const SingleActivator(LogicalKeyboardKey.enter): VoidCallbackIntent(
            widget.onSubmitText,
          ),
        if (pointer)
          const SingleActivator(LogicalKeyboardKey.numpadEnter):
              VoidCallbackIntent(widget.onSubmitText),
      },
    );
  }

  Widget _options(BuildContext context, CoilMetrics metrics) {
    final theme = CoilTheme.of(context);
    final look = widget.look;
    final question = _question;
    final options = question.options;
    final values = widget.answer.values;
    final hasText = widget.answer.text.isNotEmpty;
    final single = question.kind == CoilQuestionKind.single;
    final otherIndex = options.length;

    final selected = {
      for (final (i, option) in options.indexed)
        if (values.contains(option.value)) i,
      // A typed answer joins the picked rows' block.
      if (_hasOther && hasText) otherIndex,
    };

    final ring = CoilHighlight(
      debugLabel: 'CoilAskUserQuestions.focus',
      target: _focusVisible,
      fadeIn: false,
      motion: widget.motions.ring,
      exitMotion: widget.motions.ring,
      exitTravelMotion: widget.motions.ring,
      fade: widget.motions.tokens.fade,
      inflate: 1 + theme.focusRingWidth,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(look.itemRadius! + 2),
          side: BorderSide(
            color: theme.colors.focusRing,
            width: theme.focusRingWidth,
          ),
        ),
      ),
    );

    final rows = [
      for (final (i, option) in options.indexed)
        CoilHoverItem(
          index: i,
          child: QuestionOptionRow<T>(
            option: option,
            number: i + 1,
            kind: question.kind,
            layout: question.layout,
            keyPosition: question.keyPosition,
            selected: values.contains(option.value),
            showKeys: widget.showKeys,
            look: look,
            motions: widget.motions.row,
            focusNode: _rows[i],
            statesController: _states[i],
            size: widget.size,
            onPressed: () => single
                ? widget.onPick(option.value)
                : widget.onToggle(option.value),
          ),
        ),
      if (_hasOther)
        CoilHoverItem(
          index: otherIndex,
          child: _otherField(context, metrics, otherIndex, hasText),
        ),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: single ? SemanticsRole.radioGroup : null,
      label: question.semanticLabel,
      child: CoilRovingFocus(
        nodes: _rows,
        axis: Axis.vertical,
        tabStop: _tabStop,
        child: CoilHoverRegion(
          child: CoilHoverHighlight(
            color: look.highlight,
            radius: look.itemRadius,
            motion: widget.motions.tokens,
            background: [
              CoilSelectionBlocks(
                selected: selected,
                color: look.selection!,
                radius: look.itemRadius!,
                motion: widget.motions.tokens.copyWith(
                  standard: widget.motions.selection,
                ),
              ),
            ],
            foreground: [ring],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  Widget _otherField(
    BuildContext context,
    CoilMetrics metrics,
    int index,
    bool hasText,
  ) {
    final look = widget.look;
    final question = _question;
    final single = question.kind == CoilQuestionKind.single;
    final focused = _field.hasFocus;
    final lit = CoilHoverItem.isActive(context, index);
    final transparent = look.fieldFocusFill!.withValues(alpha: 0);
    // An empty field shows input chrome while it has focus ("type here");
    // with text it sits on the picked rows' block, like a picked row.
    final chrome = focused && !hasText;
    final placeholder = question.otherPlaceholder!;
    final keyAtStart = question.keyPosition == CoilQuestionKeyPosition.start;
    // On touch a single-choice question shows no keys at all.
    final key = !widget.showKeys && single
        ? null
        : QuestionKey(
            number: index + 1,
            kind: question.kind,
            filled: hasText,
            showKeys: widget.showKeys,
            // With the key at the start, the arrow has no slot of its own
            // here: Enter submits.
            hint: !keyAtStart && single && hasText && (focused || lit),
            look: look,
            motions: widget.motions.row,
            lineStyle: look.labelStyle!,
          );
    return CoilInput(
      controller: _text,
      focusNode: _field,
      size: widget.size,
      placeholder: placeholder,
      semanticLabel: question.otherSemanticLabel,
      textInputAction: TextInputAction.done,
      style: CoilInputStyle(
        radius: look.itemRadius,
        fill: WidgetStatePropertyAll(
          chrome ? look.fieldFocusFill : transparent,
        ),
        border: WidgetStatePropertyAll(
          chrome
              ? look.fieldFocusBorder
              : look.fieldFocusBorder!.withValues(alpha: 0),
        ),
      ),
      leading: keyAtStart ? key : null,
      trailing: keyAtStart ? null : key,
      onChanged: widget.onTextChanged,
      onSubmitted: (_) => widget.onSubmitText(),
      // Up and Down leave the field for the rows (the field is one line,
      // so they have nothing to do in it). They pass to the IME while it
      // composes.
      shortcuts: _rows.isEmpty
          ? const {}
          : {
              const SingleActivator(LogicalKeyboardKey.arrowUp):
                  VoidCallbackIntent(() => _rows.last.requestFocus()),
              const SingleActivator(LogicalKeyboardKey.arrowDown):
                  VoidCallbackIntent(() => _rows.first.requestFocus()),
            },
    );
  }
}
