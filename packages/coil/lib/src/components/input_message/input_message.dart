import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Whether a [CoilInputMessage]'s conversation is waiting on a reply.
enum CoilMessageStatus {
  /// Ready to send.
  idle,

  /// A reply is streaming in. The send button stops it, or queues the
  /// draft when there is one and the composer has `onQueue`.
  streaming,
}

/// A chat composer: a growing text field with a send button, and slots for
/// attachments and extra actions.
///
/// With a hovering pointer, Enter sends and Shift+Enter starts a new line.
/// On touch, Return starts a new line and the button sends, as in native
/// messaging apps. An Enter that only commits an IME composition never
/// sends. [onSend] gets the trimmed text, and the field clears.
///
/// While [status] is [CoilMessageStatus.streaming], sending queues: with a
/// draft, the button becomes a queue button (the same arrow) and Enter
/// hands the trimmed text to [onQueue], then clears the field. With an
/// empty field the button stops the reply with [onStop]. Without
/// [onQueue], nothing sends until the reply ends. Show the queue with a
/// `CoilQueuedStack`, and send its front message when the reply ends.
class CoilInputMessage extends StatefulWidget {
  /// Creates a composer.
  const CoilInputMessage({
    required this.onSend,
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder = 'Message…',
    this.attachments,
    this.leading,
    this.trailing,
    this.status = CoilMessageStatus.idle,
    this.onStop,
    this.onQueue,
    this.minLines = 1,
    this.maxLines = 8,
    this.sendLabel = 'Send',
    this.stopLabel = 'Stop',
    this.queueLabel = 'Queue message',
    this.enabled = true,
    this.size,
    this.motion,
  });

  /// Called with the trimmed text when the user sends.
  final ValueChanged<String> onSend;

  /// The text controller; one is created if null.
  final TextEditingController? controller;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Shown in the empty field.
  final String placeholder;

  /// Shown above the text, such as attached files' thumbnails.
  final Widget? attachments;

  /// Actions at the start of the bottom row, such as an attach button.
  final Widget? leading;

  /// Actions before the send button.
  final Widget? trailing;

  /// Whether a reply is streaming in.
  final CoilMessageStatus status;

  /// Stops a streaming reply.
  final VoidCallback? onStop;

  /// Called with the trimmed text when the user sends while a reply
  /// streams. Null keeps sending blocked until the reply ends.
  final ValueChanged<String>? onQueue;

  /// How many lines the field starts with.
  final int minLines;

  /// How many lines it grows to before it scrolls.
  final int maxLines;

  /// The send button's label for screen readers.
  final String sendLabel;

  /// The stop button's label for screen readers.
  final String stopLabel;

  /// The queue button's label for screen readers.
  final String queueLabel;

  /// Whether the composer accepts input.
  final bool enabled;

  /// Pins the size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilInputMessage> createState() => _CoilInputMessageState();
}

class _CoilInputMessageState extends State<CoilInputMessage> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  final _states = WidgetStatesController();

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  bool get _streaming => widget.status == CoilMessageStatus.streaming;

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocus?.dispose();
    _states.dispose();
    super.dispose();
  }

  /// Sends the draft, or queues it while a reply streams.
  void _send() {
    final text = _controller.text.trim();
    if (!widget.enabled || text.isEmpty) return;
    if (!_streaming) {
      widget.onSend(text);
    } else if (widget.onQueue case final queue?) {
      queue(text);
    } else {
      return;
    }
    _controller.clear();
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CoilInputMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
      _onFocus();
    }
  }

  void _onFocus() => _states.update(WidgetState.focused, _focus.hasFocus);

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final look = CoilInputStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context));
    final pointer = metrics.tier == CoilTier.pointer;
    final radius = BorderRadius.circular(look.multilineRadius!);
    final textStyle = look.textStyle!;

    // Send, queue or stop. Send and queue share the arrow; only the swap
    // to and from stop animates, with the blur-fade on `quick`.
    final button = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final hasText = _controller.text.trim().isNotEmpty;
        final stop = _streaming && !(hasText && widget.onQueue != null);
        return CoilButton.icon(
          size: CoilSize.compact,
          onPressed: stop
              ? widget.onStop
              : widget.enabled && hasText
              ? _send
              : null,
          semanticLabel: stop
              ? widget.stopLabel
              : _streaming
              ? widget.queueLabel
              : widget.sendLabel,
          icon: MotionSwitcher(
            motion: motion.quick,
            exitMotion: motion.quickExit,
            transitionBuilder: CoilBlurFade.transition(),
            child: stop
                ? const CoilDrawnGlyph(CoilGlyph.stop, key: ValueKey('stop'))
                : const CoilDrawnGlyph(
                    CoilGlyph.arrowUp,
                    key: ValueKey('send'),
                  ),
          ),
        );
      },
    );

    // The composer is the field's chrome: a tap anywhere in it lands in
    // the text, and its border follows the field's focus and hover.
    Widget decorate(BuildContext context, Widget field) => ListenableBuilder(
      listenable: _states,
      builder: (context, child) {
        final states = {
          ..._states.value,
          if (!widget.enabled) WidgetState.disabled,
        };
        return MotionBuilder<Color>(
          value: look.border!.resolve(states)!,
          converter: MotionConverter.colorRgb,
          motion: motion.fade,
          builder: (context, border, child) => DecoratedBox(
            decoration: ShapeDecoration(
              color: look.fill!.resolve(states),
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(color: border),
              ),
            ),
            child: child,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(metrics.gap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: metrics.gap,
          children: [
            ?widget.attachments,
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.controlPaddingX - metrics.gap,
              ),
              child: field,
            ),
            Row(
              spacing: metrics.gap,
              children: [
                ?widget.leading,
                const Spacer(),
                ?widget.trailing,
                button,
              ],
            ),
          ],
        ),
      ),
    );

    return CoilInteractionDetector(
      states: _states,
      enabled: widget.enabled,
      trackPress: false,
      child: Opacity(
        opacity: widget.enabled ? 1 : metrics.disabledOpacity,
        child: CoilTextFieldCore(
          controller: _controller,
          focusNode: _focus,
          enabled: widget.enabled,
          placeholder: Text(widget.placeholder),
          placeholderColor: look.placeholder,
          style: textStyle,
          strutStyle: StrutStyle.fromTextStyle(
            textStyle,
            forceStrutHeight: true,
          ),
          cursorColor: look.cursorColor,
          cursorWidth: look.cursorWidth!,
          selectionColor: look.selectionColor,
          keyboardAppearance: theme.brightness,
          textCapitalization: TextCapitalization.sentences,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          scrollPadding: const EdgeInsets.all(16),
          // With a hovering pointer, Enter sends and Shift+Enter is a new
          // line; on touch, Return is a new line and the button sends.
          shortcuts: {
            if (pointer)
              const SingleActivator(LogicalKeyboardKey.enter):
                  VoidCallbackIntent(_send),
            if (pointer)
              const SingleActivator(LogicalKeyboardKey.numpadEnter):
                  VoidCallbackIntent(_send),
          },
          decorationBuilder: decorate,
        ),
      ),
    );
  }
}
