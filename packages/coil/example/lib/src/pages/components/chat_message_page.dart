import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const chatMessageEntry = CatalogEntry(
  slug: 'chat-message',
  title: 'ChatMessage',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A bubble for the person, plain text for the assistant.',
  page: ChatMessagePage.new,
);

const _question = 'Can you summarize the design review?';

/// What the assistant says, as the text it copies and the lines it shows.
typedef _Reply = ({String intro, List<(String, String)> points});

const _replies = <_Reply>[
  (
    intro: 'Three changes came out of the review:',
    points: [
      ('Tighter exits.', 'Dismiss springs settle sooner than entrances.'),
      ('One row height.', 'Menus and selects now share a single row.'),
      ('Sheets on phones.', 'Forms open in a sheet instead of a popover.'),
    ],
  ),
  (
    intro: 'The review settled on three things:',
    points: [
      ('Exits.', 'They run on shorter springs than entrances do.'),
      ('Rows.', 'Every menu and select uses the same row height.'),
      ('Phones.', 'Forms move into sheets, popovers stay on desktop.'),
    ],
  ),
];

String _plain(_Reply reply) => [
  reply.intro,
  for (final (lead, rest) in reply.points) '$lead $rest',
].join('\n');

class ChatMessagePage extends StatefulWidget {
  const ChatMessagePage({super.key});

  @override
  State<ChatMessagePage> createState() => _ChatMessagePageState();
}

enum _Sender {
  user('User', CoilChatSender.user),
  assistant('Assistant', CoilChatSender.assistant);

  const _Sender(this.label, this.sender);

  final String label;
  final CoilChatSender sender;
}

class _ChatMessagePageState extends State<ChatMessagePage> {
  var _sender = _Sender.assistant;
  var _time = true;
  var _actions = true;
  var _attachment = false;
  var _run = 0;
  final _copy = CoilCopyController();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _sender == _Sender.user;
    final text = user ? _question : _plain(_replies.first);
    return CatalogPage(
      title: 'ChatMessage',
      summary:
          'Messages in a transcript, as a bubble for the person and plain '
          'text for the assistant. Their actions appear on hover, or after a '
          'long press on touch.',
      hero: const _Conversation(),
      usage: '''
CoilChatMessage(
  sender: CoilChatSender.assistant,
  time: Text('10:42'),
  timeLabel: '10:42',
  actions: [
    CoilChatMessageAction(
      label: Text('Copy'),
      // The icon names the button, as in an IconButton.
      icon: Semantics(
        label: 'Copy',
        child: CoilCopyGlyph.listening(controller: copy),
      ),
      onPressed: () => copy.copy(reply, context: context),
    ),
  ],
  child: Text(reply),
)''',
      notes: const [
        CatalogNote(
          'Pointer',
          'The meta row appears on hover, and stays while one of its actions '
              'has keyboard focus.',
        ),
        CatalogNote(
          'Touch',
          'The meta row is always visible, and a long press opens the same '
              'actions as a menu.',
        ),
        CatalogNote(
          'Motion',
          'A new message fades in, rising 8 and growing from 0.96 out of its '
              'sender corner on standard, while the ones above it slide to '
              'make room. Use an entrance of none for messages that were '
              'already in the transcript.',
        ),
        CatalogNote(
          'Accessibility',
          'Each message is a single container labelled with its sender and '
              'time, and Copy uses the shared copy feedback, so its icon '
              'turns into a check.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          controls: DemoControls(
            children: [
              DemoControl.choice(
                label: 'Sender',
                value: _sender,
                values: _Sender.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() {
                  _sender = v;
                  _run++;
                }),
              ),
              DemoControl.toggle(
                label: 'Time',
                value: _time,
                onChanged: (v) => setState(() => _time = v),
              ),
              DemoControl.toggle(
                label: 'Actions',
                value: _actions,
                onChanged: (v) => setState(() => _actions = v),
              ),
              DemoControl.toggle(
                label: 'Attachment',
                value: _attachment,
                onChanged: (v) => setState(() => _attachment = v),
              ),
              DemoControl(
                label: 'Entrance',
                child: CoilButton(
                  variant: CoilButtonVariant.secondary,
                  size: CoilSize.compact,
                  onPressed: () => setState(() => _run++),
                  child: const Text('Replay'),
                ),
              ),
            ],
          ),
          child: CoilChatMessage(
            key: ValueKey((_run, _sender)),
            sender: _sender.sender,
            time: _time ? const Text('10:42') : null,
            timeLabel: _time ? '10:42' : null,
            attachments: [
              if (_attachment)
                const CoilFileThumbnail(
                  name: 'dunes.jpg',
                  dimension: 80,
                  image: AssetImage('assets/images/dunes.jpg'),
                ),
            ],
            actions: [
              if (_actions)
                CoilChatMessageAction(
                  label: const Text('Copy'),
                  icon: Semantics(
                    label: 'Copy',
                    child: CoilCopyGlyph.listening(controller: _copy),
                  ),
                  onPressed: () =>
                      unawaited(_copy.copy(text, context: context)),
                ),
            ],
            child: user ? const Text(_question) : _ReplyText(_replies.first),
          ),
        ),
      ],
    );
  }
}

/// The assistant's reply with its lead words in semibold, as a markdown
/// list would render.
class _ReplyText extends StatelessWidget {
  const _ReplyText(this.reply);

  final _Reply reply;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(reply.intro),
        for (final (lead, rest) in reply.points)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$lead ',
                  style: TextStyle(fontWeight: text.emphasis),
                ),
                TextSpan(text: rest),
              ],
            ),
          ),
      ],
    );
  }
}

/// A transcript: the assistant's answer can be copied or retried, and a
/// retry thinks for a moment and then answers again.
class _Conversation extends StatefulWidget {
  const _Conversation();

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  static const _latency = Duration(milliseconds: 1600);

  final _copyQuestion = CoilCopyController();
  final _copyReply = CoilCopyController();
  var _version = 0;
  var _thinking = false;
  var _retried = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _copyQuestion.dispose();
    _copyReply.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _thinking = true);
    _timer?.cancel();
    _timer = Timer(_latency, () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _retried = true;
        _version = (_version + 1) % _replies.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final reply = _replies[_version];
    return DemoColumn(
      children: [
        CoilChatMessage(
          sender: CoilChatSender.user,
          entrance: CoilChatMessageEntrance.none,
          time: const Text('10:41'),
          timeLabel: '10:41',
          actions: [
            CoilChatMessageAction(
              label: const Text('Copy'),
              icon: Semantics(
                label: 'Copy',
                child: CoilCopyGlyph.listening(controller: _copyQuestion),
              ),
              onPressed: () =>
                  unawaited(_copyQuestion.copy(_question, context: context)),
            ),
          ],
          child: const Text(_question),
        ),
        if (_thinking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: CoilThinkingIndicator(
              leading: CatalogIcon(Glyph.sparkles),
              words: [Text('Thinking'), Text('Reading the notes')],
            ),
          )
        else
          CoilChatMessage(
            key: ValueKey(_version),
            sender: CoilChatSender.assistant,
            entrance: _retried
                ? CoilChatMessageEntrance.animated
                : CoilChatMessageEntrance.none,
            time: const Text('10:42'),
            timeLabel: '10:42',
            actions: [
              CoilChatMessageAction(
                label: const Text('Copy'),
                icon: Semantics(
                  label: 'Copy',
                  child: CoilCopyGlyph.listening(controller: _copyReply),
                ),
                onPressed: () =>
                    unawaited(_copyReply.copy(_plain(reply), context: context)),
              ),
              CoilChatMessageAction(
                label: const Text('Retry'),
                icon: const CatalogIcon(Glyph.refresh, semanticLabel: 'Retry'),
                onPressed: _retry,
              ),
            ],
            child: _ReplyText(reply),
          ),
      ],
    );
  }
}
