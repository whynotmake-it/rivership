// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/ask_user_questions/ask_user_questions_controller.dart';
import 'package:coil/src/components/ask_user_questions/ask_user_questions_style.dart';
import 'package:coil/src/components/ask_user_questions/question.dart';
import 'package:coil/src/components/ask_user_questions/question_row.dart';
import 'package:coil/src/components/ask_user_questions/question_step.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The animated parts of a [CoilAskUserQuestions], as Motor tracks. Use
/// them as keys of [CoilAskUserQuestions.motions] or
/// [CoilThemeData.trackMotions].
final class CoilAskUserQuestionsTrack<T extends Object> extends Track<T> {
  CoilAskUserQuestionsTrack._(
    super.converter, {
    required String super.debugLabel,
  });

  /// The card's height between questions. Default motion: `standard`.
  static final height = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.height',
  );

  /// The questions fading in and out. Default motion: `fade`, `fadeExit`
  /// for the leaving one.
  static final step = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.step',
  );

  /// The merged blocks behind picked rows. Default motion: `standard`.
  static final selection = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.selection',
  );

  /// The focus ring travelling between rows. Default motion: `quick`.
  static final ring = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.ring',
  );

  /// Label weight and key colors. Default motion: `fade`.
  static final label = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.label',
  );

  /// The submit arrow over a key. Default motion: `quick`, `quickExit`
  /// when it leaves.
  static final hint = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.hint',
  );

  /// The touch press fill. Default motion: `fade`, `fadeExit` on release.
  static final press = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.press',
  );

  /// The footer buttons appearing and leaving. Default motion: `quick`,
  /// `quickExit` when they leave.
  static final buttons = CoilAskUserQuestionsTrack<double>._(
    .single,
    debugLabel: 'CoilAskUserQuestions.buttons',
  );
}

/// The words a [CoilAskUserQuestions] shows and announces. The defaults
/// are English.
@immutable
class CoilAskUserQuestionsLabels {
  /// Creates the labels.
  const CoilAskUserQuestionsLabels({
    this.back = 'Back',
    this.skip = 'Skip',
    this.next = 'Continue',
    this.finish = 'Finish',
    this.freeText = 'Type your answer',
    this.empty = 'No questions.',
    this.step = _step,
  });

  /// The button that returns to the previous question.
  final String back;

  /// The button that skips a question.
  final String skip;

  /// The button that answers a question that isn't the last.
  final String next;

  /// The button that answers the last question.
  final String finish;

  /// A free-text field's placeholder when its question sets none.
  final String freeText;

  /// Shown when there are no questions.
  final String empty;

  /// The progress line, from the question's number (from 1) and the count.
  /// It's announced as the questions change.
  final String Function(int number, int count) step;

  static String _step(int number, int count) => 'Question $number of $count';

  @override
  bool operator ==(Object other) =>
      other is CoilAskUserQuestionsLabels &&
      other.back == back &&
      other.skip == skip &&
      other.next == next &&
      other.finish == finish &&
      other.freeText == freeText &&
      other.empty == empty &&
      other.step == step;

  @override
  int get hashCode =>
      Object.hash(back, skip, next, finish, freeText, empty, step);
}

/// A card that asks the user a few questions, one at a time: the
/// "ask the user" step of an assistant.
///
/// Each question takes one option ([CoilQuestion.single]), several
/// ([CoilQuestion.multiple]) or typed text ([CoilQuestion.freeText]). An
/// option question can add a typed "other" row. Picking a single option
/// moves on at once; the others move on with Continue. Back returns, and
/// Skip passes a question. Between questions the card's height springs
/// while the old question fades out and the new one fades in.
///
/// Rows share the gliding hover highlight, and picked rows that touch
/// share one block. On pointer each row shows its number key, and a lit
/// single-choice row shows a submit arrow. Touch hides the keys, makes rows
/// 44 tall, and shows a press fill under the finger.
///
/// Keyboard: 1–9 pick the row with that number (the row after the options
/// focuses the "other" field). Up and Down move between rows, Enter or
/// Space picks, and Ctrl+Enter (⌘+Enter on Apple platforms) continues.
/// Escape, or the arrow pointing back, returns; the arrow pointing forward
/// skips. Inside a text field, Enter answers. These keys work while focus
/// is in the card; when a question changes, focus moves to the new one.
///
/// The answers live in a [CoilAskUserQuestionsController]; pass one to read
/// or restore them. [onCompleted] fires when the last question is answered
/// or skipped.
class CoilAskUserQuestions<T> extends StatefulWidget {
  /// Creates the card.
  const CoilAskUserQuestions({
    required this.questions,
    super.key,
    this.controller,
    this.onCompleted,
    this.onSkipped,
    this.labels = const CoilAskUserQuestionsLabels(),
    this.autofocus = false,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The questions, in order.
  final List<CoilQuestion<T>> questions;

  /// The current question and the answers. One is created if null.
  final CoilAskUserQuestionsController<T>? controller;

  /// Called with every answer, keyed by [CoilQuestion.id], when the last
  /// question is answered or skipped.
  final ValueChanged<Map<Object, CoilAnswer<T>>>? onCompleted;

  /// Called with a question's [CoilQuestion.id] when it's skipped.
  final ValueChanged<Object>? onSkipped;

  /// The words the card shows and announces.
  final CoilAskUserQuestionsLabels labels;

  /// Whether to move focus into the first question when first built, so
  /// the number keys work at once.
  final bool autofocus;

  /// Pins the card to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilAskUserQuestionsTrack]s.
  final Map<CoilAskUserQuestionsTrack<Object>, Motion>? motions;

  /// Overrides for this card's look.
  final CoilAskUserQuestionsStyle? style;

  @override
  State<CoilAskUserQuestions<T>> createState() =>
      _CoilAskUserQuestionsState<T>();
}

class _CoilAskUserQuestionsState<T> extends State<CoilAskUserQuestions<T>> {
  CoilAskUserQuestionsController<T>? _ownController;
  final _scope = FocusNode(
    debugLabel: 'CoilAskUserQuestions',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _steps = <Object, GlobalKey<QuestionStepState<T>>>{};

  /// A free-text answer's validation message, for the question with
  /// [_errorFor].
  String? _error;
  Object? _errorFor;

  CoilAskUserQuestionsController<T> get _controller =>
      widget.controller ??
      (_ownController ??= CoilAskUserQuestionsController<T>());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onController);
    if (widget.autofocus) _focusStepAfterBuild();
  }

  @override
  void didUpdateWidget(CoilAskUserQuestions<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onController);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onController);
    }
    final ids = {for (final q in widget.questions) q.id};
    _steps.removeWhere((id, _) => !ids.contains(id));
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    _ownController?.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _onController() => setState(() {});

  int get _index => _controller.step.clamp(0, widget.questions.length - 1);

  CoilQuestion<T> get _question => widget.questions[_index];

  CoilAnswer<T> get _answer => _controller.answerOf(_question.id);

  bool get _isLast => _index == widget.questions.length - 1;

  GlobalKey<QuestionStepState<T>> _stepKey(Object id) =>
      _steps[id] ??= GlobalKey(debugLabel: 'CoilAskUserQuestions step $id');

  void _focusStepAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.questions.isEmpty) return;
      _stepKey(_question.id).currentState?.focusEntry();
    });
  }

  void _goTo(int index) {
    // Focus follows the flow only when it was in the card, so a tap never
    // pulls focus (or the keyboard) up.
    final hadFocus = _scope.hasFocus;
    setState(() => _error = null);
    _controller.step = index;
    if (hadFocus) _focusStepAfterBuild();
  }

  void _advance() {
    if (_isLast) {
      widget.onCompleted?.call(_controller.answers);
    } else {
      _goTo(_index + 1);
    }
  }

  void _set(CoilAnswer<T> answer) =>
      _controller.setAnswer(_question.id, answer);

  void _pick(T value) {
    unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
    // One answer: picking an option drops a typed one.
    _set(CoilAnswer(values: {value}));
    _advance();
  }

  void _toggle(T value) {
    unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
    final values = _answer.values;
    _set(
      _answer.copyWith(
        values: values.contains(value)
            ? ({...values}..remove(value))
            : {...values, value},
        skipped: false,
      ),
    );
  }

  void _setText(String text) {
    if (_error != null) setState(() => _error = null);
    final single = _question.kind == CoilQuestionKind.single;
    // In a single-choice question, typing replaces the picked option.
    _set(CoilAnswer(values: single ? const {} : _answer.values, text: text));
  }

  void _submitText() {
    final question = _question;
    if (question.kind == CoilQuestionKind.multiple) {
      _next();
      return;
    }
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    if (question.validator?.call(text) case final message?) {
      setState(() {
        _error = message;
        _errorFor = question.id;
      });
      return;
    }
    _set(CoilAnswer(values: _answer.values, text: text));
    _advance();
  }

  bool get _canNext => switch (_question.kind) {
    CoilQuestionKind.single => false,
    CoilQuestionKind.multiple => !_answer.isEmpty,
    CoilQuestionKind.freeText => _answer.text.trim().isNotEmpty,
  };

  void _next() {
    if (!_canNext) return;
    if (_question.kind == CoilQuestionKind.freeText) {
      _submitText();
    } else {
      _set(_answer.copyWith(skipped: false));
      _advance();
    }
  }

  bool get _canBack => _index > 0;

  void _back() {
    if (_canBack) _goTo(_index - 1);
  }

  bool get _canSkip => widget.questions.length > 1 && _question.skippable;

  void _skip() {
    if (!_canSkip) return;
    final id = _question.id;
    _set(_answer.copyWith(skipped: true));
    widget.onSkipped?.call(id);
    _advance();
  }

  void _pickNumber(int number) {
    final question = _question;
    final options = question.options;
    if (number <= options.length) {
      final value = options[number - 1].value;
      question.kind == CoilQuestionKind.single ? _pick(value) : _toggle(value);
    } else if (number == options.length + 1) {
      _stepKey(question.id).currentState?.focusOther();
    }
  }

  /// Whether focus is in a text field, where digits and arrows edit text.
  static bool _editingText() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;

  Map<ShortcutActivator, Intent> get _shortcuts {
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return {
      for (var n = 1; n <= 9; n++) CharacterActivator('$n'): _NumberIntent(n),
      const SingleActivator(LogicalKeyboardKey.escape): const _BackIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): const _ArrowIntent(
        TextDirection.ltr,
      ),
      const SingleActivator(LogicalKeyboardKey.arrowRight): const _ArrowIntent(
        TextDirection.rtl,
      ),
      SingleActivator(LogicalKeyboardKey.enter, meta: apple, control: !apple):
          const _NextIntent(),
    };
  }

  Map<Type, Action<Intent>> get _actions {
    final options = widget.questions.isEmpty ? 0 : _question.options.length;
    final other =
        widget.questions.isNotEmpty && _question.otherPlaceholder != null;
    return {
      _NumberIntent: _CardAction<_NumberIntent>(
        enabled: (i) =>
            !_editingText() && i.number <= options + (other ? 1 : 0),
        onInvoke: (i) => _pickNumber(i.number),
      ),
      _BackIntent: _CardAction<_BackIntent>(
        enabled: (_) => _canBack,
        onInvoke: (_) => _back(),
      ),
      _ArrowIntent: _CardAction<_ArrowIntent>(
        // The arrow pointing to the reading start goes back; the other one
        // skips. In RTL, left skips.
        enabled: (i) =>
            !_editingText() &&
            (i.backIn == Directionality.of(context) ? _canBack : _canSkip),
        onInvoke: (i) =>
            i.backIn == Directionality.of(context) ? _back() : _skip(),
      ),
      _NextIntent: _CardAction<_NextIntent>(
        enabled: (_) => _canNext,
        onInvoke: (_) => _next(),
      ),
    };
  }

  Motion _motion(
    CoilAskUserQuestionsTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final look = CoilAskUserQuestionsStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilAskUserQuestionsStyle>(context))
        .merge(widget.style);
    final labels = widget.labels;
    final questions = widget.questions;
    final inset = metrics.popupInset;

    Widget card(Widget child) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: look.maxWidth!),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: look.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(look.radius!),
            side: look.border!,
          ),
        ),
        child: child,
      ),
    );

    if (questions.isEmpty) {
      return card(
        Padding(
          padding: EdgeInsets.all(inset + metrics.controlPaddingX),
          child: Text(
            labels.empty,
            style: look.labelStyle!.copyWith(color: look.description),
          ),
        ),
      );
    }

    final question = _question;
    final answer = _answer;
    final showKeys = metrics.tier == CoilTier.pointer;
    final stepMotions = QuestionStepMotions(
      tokens: tokens,
      selection: _motion(CoilAskUserQuestionsTrack.selection, tokens.standard),
      ring: _motion(CoilAskUserQuestionsTrack.ring, tokens.quick),
      row: QuestionRowMotions(
        label: _motion(
          CoilAskUserQuestionsTrack.label,
          tokens.fade,
          spatial: false,
        ),
        hint: _motion(CoilAskUserQuestionsTrack.hint, tokens.quick),
        hintExit: _motion(CoilAskUserQuestionsTrack.hint, tokens.quickExit),
        press: _motion(
          CoilAskUserQuestionsTrack.press,
          tokens.fade,
          spatial: false,
        ),
        release: _motion(
          CoilAskUserQuestionsTrack.press,
          tokens.fadeExit,
          spatial: false,
        ),
      ),
    );
    final error = _errorFor == question.id ? _error : null;
    final buttonMotion = _motion(
      CoilAskUserQuestionsTrack.buttons,
      tokens.quick,
    );
    final buttonExit = _motion(
      CoilAskUserQuestionsTrack.buttons,
      tokens.quickExit,
    );

    Widget pop(Widget? child) => _Presence(
      axis: Axis.horizontal,
      motion: buttonMotion,
      exitMotion: buttonExit,
      sizeMotion: buttonMotion,
      scale: 0.85,
      child: child,
    );

    // Back at the start, Skip and Continue at the end. When they don't fit
    // (large text in a narrow card), they stack, ending at the end edge.
    final footer = OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.end,
      overflowSpacing: 4,
      children: [
        pop(
          _canBack
              ? CoilButton(
                  key: const ValueKey('back'),
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  onPressed: _back,
                  child: Text(labels.back),
                )
              : null,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pop(
              _canSkip
                  ? CoilButton(
                      key: const ValueKey('skip'),
                      variant: CoilButtonVariant.ghost,
                      size: CoilSize.compact,
                      onPressed: _skip,
                      child: Text(labels.skip),
                    )
                  : null,
            ),
            pop(
              question.kind == CoilQuestionKind.single
                  ? null
                  : Padding(
                      key: const ValueKey('next'),
                      padding: EdgeInsetsDirectional.only(
                        start: metrics.buttonGap,
                      ),
                      child: CoilButton(
                        size: CoilSize.compact,
                        onPressed: _canNext ? _next : null,
                        child: Text(
                          question.nextLabel ??
                              (_isLast ? labels.finish : labels.next),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );

    final step = QuestionStep<T>(
      key: _stepKey(question.id),
      question: question,
      answer: answer,
      showKeys: showKeys,
      look: look,
      motions: stepMotions,
      size: widget.size,
      error: error,
      freeTextPlaceholder: labels.freeText,
      onPick: _pick,
      onToggle: _toggle,
      onTextChanged: _setText,
      onSubmitText: _submitText,
    );

    return Actions(
      actions: _actions,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Focus(
          focusNode: _scope,
          includeSemantics: false,
          child: MotorInspectionScope(
            group: 'CoilAskUserQuestions',
            child: card(
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: inset,
                  end: inset,
                  bottom: inset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        metrics.controlPaddingX,
                        metrics.controlPaddingX,
                        metrics.controlPaddingX,
                        4,
                      ),
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        child: Text(
                          labels.step(_index + 1, questions.length),
                          style: look.stepStyle,
                        ),
                      ),
                    ),
                    _Presence(
                      axis: Axis.vertical,
                      motion: _motion(
                        CoilAskUserQuestionsTrack.step,
                        tokens.fade,
                        spatial: false,
                      ),
                      exitMotion: _motion(
                        CoilAskUserQuestionsTrack.step,
                        tokens.fadeExit,
                        spatial: false,
                      ),
                      sizeMotion: _motion(
                        CoilAskUserQuestionsTrack.height,
                        tokens.standard,
                      ),
                      scale: 1,
                      child: step,
                    ),
                    const SizedBox(height: 4),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Switches its child with the blur-fade while its size springs to the new
/// child's at once. A leaving child keeps its own size (clipped by the
/// shrinking box along [axis]) and can't be focused, tapped or read.
class _Presence extends StatelessWidget {
  const _Presence({
    required this.axis,
    required this.motion,
    required this.exitMotion,
    required this.sizeMotion,
    required this.scale,
    required this.child,
  });

  final Axis axis;
  final Motion motion;
  final Motion exitMotion;
  final Motion sizeMotion;
  final double scale;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    final alignment = AlignmentDirectional.topStart.resolve(
      Directionality.of(context),
    );
    return MotionSwitcher(
      motion: motion,
      exitMotion: exitMotion,
      debugLabel: vertical ? 'CoilAskUserQuestions.step' : 'buttons',
      transitionBuilder: (child, presence) => _Leaving(
        presence: presence,
        child: CoilBlurFade(
          presence: presence,
          scale: scale,
          blur: vertical ? 4 : 0,
          alignment: AlignmentDirectional.centerStart,
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        // The step region clips the taller leaving question as the card
        // shrinks; buttons fade in place, unclipped.
        clipBehavior: vertical ? Clip.hardEdge : Clip.none,
        children: [
          for (final leaving in previous)
            PositionedDirectional(
              start: 0,
              end: vertical ? 0 : null,
              top: 0,
              child: leaving,
            ),
          MotionSize(
            key: const ValueKey('size'),
            motion: sizeMotion,
            alignment: alignment,
            clipBehavior: Clip.none,
            debugLabel: vertical
                ? 'CoilAskUserQuestions.height'
                : 'CoilAskUserQuestions.buttons',
            child: current ?? const SizedBox.shrink(),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Takes a leaving child out of focus, hit testing and semantics.
class _Leaving extends StatefulWidget {
  const _Leaving({required this.presence, required this.child});

  final Animation<double> presence;
  final Widget child;

  @override
  State<_Leaving> createState() => _LeavingState();
}

class _LeavingState extends State<_Leaving> {
  bool get _leaving => widget.presence.status == AnimationStatus.reverse;

  @override
  void initState() {
    super.initState();
    widget.presence.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_Leaving oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presence != widget.presence) {
      oldWidget.presence.removeStatusListener(_onStatus);
      widget.presence.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.presence.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus _) => setState(() {});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: _leaving,
    child: ExcludeFocus(
      excluding: _leaving,
      child: ExcludeSemantics(excluding: _leaving, child: widget.child),
    ),
  );
}

class _NumberIntent extends Intent {
  const _NumberIntent(this.number);
  final int number;
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

/// An arrow key; [backIn] is the text direction in which it points back.
class _ArrowIntent extends Intent {
  const _ArrowIntent(this.backIn);
  final TextDirection backIn;
}

/// An action that's enabled by a predicate, so a disabled key passes on
/// (to a text field, or an enclosing dialog's Escape).
class _CardAction<I extends Intent> extends Action<I> {
  _CardAction({required this.enabled, required this.onInvoke});

  final bool Function(I intent) enabled;
  final void Function(I intent) onInvoke;

  @override
  bool isEnabled(I intent) => enabled(intent);

  @override
  Object? invoke(I intent) {
    onInvoke(intent);
    return null;
  }
}
