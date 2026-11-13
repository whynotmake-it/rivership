import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Whether a [CoilInputMessage]'s conversation is waiting on a reply.
enum CoilMessageStatus {
  /// Ready to send.
  idle,

  /// A reply is streaming in: the send button becomes a stop button.
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
/// While [status] is [CoilMessageStatus.streaming], the button stops the
/// reply with [onStop] instead, and Enter doesn't send.
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
    this.minLines = 1,
    this.maxLines = 8,
    this.sendLabel = 'Send',
    this.stopLabel = 'Stop',
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

  /// How many lines the field starts with.
  final int minLines;

  /// How many lines it grows to before it scrolls.
  final int maxLines;

  /// The send button's label for screen readers.
  final String sendLabel;

  /// The stop button's label for screen readers.
  final String stopLabel;

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
    _ownController?.dispose();
    _ownFocus?.dispose();
    _states.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (!widget.enabled || _streaming || text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

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
    const clear = WidgetStatePropertyAll<Color?>(Color(0x00000000));

    final field = CoilInput.multiline(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      placeholder: Text(widget.placeholder),
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      size: widget.size,
      motion: widget.motion,
      statesController: _states,
      // The composer draws the border and fill around everything.
      style: const CoilInputStyle(border: clear, fill: clear),
      shortcuts: {
        if (pointer)
          const SingleActivator(LogicalKeyboardKey.enter): VoidCallbackIntent(
            _send,
          ),
        if (pointer)
          const SingleActivator(LogicalKeyboardKey.numpadEnter):
              VoidCallbackIntent(_send),
      },
    );

    final button = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _streaming
          ? CoilButton.icon(
              size: CoilSize.compact,
              onPressed: widget.onStop,
              semanticLabel: widget.stopLabel,
              icon: const CoilDrawnGlyph(CoilGlyph.stop),
            )
          : CoilButton.icon(
              size: CoilSize.compact,
              onPressed: widget.enabled && _controller.text.trim().isNotEmpty
                  ? _send
                  : null,
              semanticLabel: widget.sendLabel,
              icon: const CoilDrawnGlyph(CoilGlyph.arrowUp),
            ),
    );

    return ListenableBuilder(
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
            field,
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
  }
}
