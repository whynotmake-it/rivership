import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/composer_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const inputMessageEntry = CatalogEntry(
  slug: 'input-message',
  title: 'InputMessage',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A chat composer where Enter sends the message, and on touch Return '
      'starts a new line instead.',
  page: InputMessagePage.new,
);

class InputMessagePage extends StatefulWidget {
  const InputMessagePage({super.key});

  @override
  State<InputMessagePage> createState() => _InputMessagePageState();
}

class _InputMessagePageState extends State<InputMessagePage> {
  var _compact = false;
  var _enabled = true;
  var _streaming = false;
  var _files = <DemoFile>[];

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputMessage',
    summary:
        'Enter sends the message and Shift+Enter breaks the line, while on '
        'touch Return starts a new line and the button sends. The same '
        'button stops the answer while a reply is streaming in.',
    hero: const _Conversation(),
    usage: '''
CoilInputMessage(
  status: replying
      ? CoilMessageStatus.streaming
      : CoilMessageStatus.idle,
  onSend: send,
  onStop: stop,
  attachments: attachments,
  leading: attachButton,
)''',
    notes: const [
      CatalogNote(
        'Keyboard',
        'Enter sends the message and Shift+Enter inserts a newline. Pressing '
            'Up in an empty field brings back the last message you sent.',
      ),
      CatalogNote(
        'Touch',
        'Return inserts a newline, so sending goes through the button. The '
            'remove button on an attachment tile is always visible and keeps '
            'a 44 px hit target.',
      ),
      CatalogNote(
        'Motion',
        'The attachment tray springs open smoothly and fades its contents '
            'in, and the send button morphs between its send, stop, and queue '
            'shapes.',
      ),
      CatalogNote(
        'Accessibility',
        'The field is announced as a multiline text field labeled "Message", '
            'and the button’s label follows whatever it currently does, so it '
            'reads as Send, Stop, or Queue message.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.toggle(
              label: 'Streaming',
              value: _streaming,
              onChanged: (v) => setState(() => _streaming = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _compact,
              onChanged: (v) => setState(() => _compact = v),
            ),
            DemoControl.toggle(
              label: 'Enabled',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
        child: CoilInputMessage(
          size: _compact ? CoilSize.compact : CoilSize.regular,
          enabled: _enabled,
          status: _streaming
              ? CoilMessageStatus.streaming
              : CoilMessageStatus.idle,
          onStop: () => setState(() => _streaming = false),
          onSend: (_) {},
          onQueue: (_) {},
          placeholder: const Text('Ask anything about the brief'),
          attachments: _files.isEmpty
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in _files)
                      demoThumbnail(
                        file,
                        onRemove: () => setState(
                          () => _files = [..._files]..remove(file),
                        ),
                      ),
                  ],
                ),
          leading: _AttachButton(
            files: _files,
            onChanged: (files) => setState(() => _files = files),
          ),
        ),
      ),
    ],
  );
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.files, required this.onChanged});

  final List<DemoFile> files;
  final ValueChanged<List<DemoFile>> onChanged;

  @override
  Widget build(BuildContext context) {
    final next = nextDemoFile(files);
    return CoilButton.icon(
      variant: CoilButtonVariant.ghost,
      size: CoilSize.compact,
      semanticLabel: 'Attach a file',
      icon: const CatalogIcon(Glyph.paperclip),
      onPressed: next == null ? null : () => onChanged([...files, next]),
    );
  }
}

typedef _Turn = ({
  CoilChatSender from,
  String text,
  List<DemoFile> files,
  bool seeded,
});

/// A conversation: attach files, send, and a reply streams in.
class _Conversation extends StatefulWidget {
  const _Conversation();

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  var _turns = <_Turn>[
    (
      from: CoilChatSender.user,
      text: 'Which sections of the launch brief need the most work?',
      files: const <DemoFile>[],
      seeded: true,
    ),
    (
      from: CoilChatSender.assistant,
      text:
          'Pricing is thin and the timeline has no owners. The intro is '
          'solid. Attach the latest draft and I will mark it up.',
      files: const <DemoFile>[],
      seeded: true,
    ),
  ];
  var _files = <DemoFile>[];
  var _replying = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _send(String text) {
    final sent = _files;
    setState(() {
      _turns = [
        ..._turns,
        (from: CoilChatSender.user, text: text, files: sent, seeded: false),
      ];
      _files = [];
      _replying = true;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2200), () => _reply(sent));
  }

  void _reply(List<DemoFile> read) {
    if (!mounted) return;
    setState(() {
      _turns = [
        ..._turns,
        (
          from: CoilChatSender.assistant,
          text: read.isEmpty
              ? 'Here is a first pass. Tell me which part to expand.'
              : 'I read ${read.map((f) => f.name).join(' and ')}. '
                    'Nothing blocks the launch; tighten the pricing '
                    'paragraph and name an owner for each date.',
          files: const <DemoFile>[],
          seeded: false,
        ),
      ];
      _replying = false;
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _turns = [
        ..._turns,
        (
          from: CoilChatSender.assistant,
          text: 'Stopped.',
          files: const <DemoFile>[],
          seeded: false,
        ),
      ];
      _replying = false;
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Expanded(
          child: ListView(
            reverse: true,
            children: [
              if (_replying)
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CoilThinkingIndicator(
                    words: [Text('Reading'), Text('Drafting')],
                  ),
                ),
              for (final turn in _turns.reversed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CoilChatMessage(
                    sender: turn.from,
                    entrance: turn.seeded
                        ? CoilChatMessageEntrance.none
                        : CoilChatMessageEntrance.animated,
                    attachments: [
                      for (final file in turn.files) demoThumbnail(file),
                    ],
                    child: Text(turn.text),
                  ),
                ),
            ],
          ),
        ),
        CoilInputMessage(
          status: _replying
              ? CoilMessageStatus.streaming
              : CoilMessageStatus.idle,
          placeholder: const Text('Reply to the assistant'),
          onSend: _send,
          onStop: _stop,
          attachments: _files.isEmpty
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in _files)
                      demoThumbnail(
                        file,
                        onRemove: () => setState(
                          () => _files = [..._files]..remove(file),
                        ),
                      ),
                  ],
                ),
          leading: _AttachButton(
            files: _files,
            onChanged: (files) => setState(() => _files = files),
          ),
        ),
      ],
    ),
  );
}
