import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/composer_demo.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const queuedStackEntry = CatalogEntry(
  slug: 'queued-stack',
  title: 'QueuedStack',
  group: CatalogGroup.shellAndComposites,
  summary:
      'A pile above the composer that holds the messages you send while the '
      'assistant is still replying.',
  page: QueuedStackPage.new,
);

class QueuedStackPage extends StatelessWidget {
  const QueuedStackPage({super.key});

  @override
  Widget build(BuildContext context) => const CatalogPage(
    title: 'QueuedStack',
    summary:
        'Send something while the assistant is replying and the message '
        'waits in a pile above the composer. Hovering the pile, or tapping it '
        'on touch, fans it out so you can reorder, edit or remove what is '
        'still waiting.',
    hero: _Chat(),
    usage: '''
CoilQueuedStack(
  messages: queue,
  onChanged: (next) => setState(() => queue = next),
  onEdit: (message) => edit(message),
  child: transcript,
)''',
    notes: [
      CatalogNote(
        'Pointer',
        'Hovering the pile or moving focus into it fans the cards out. A card '
            'reveals its actions on hover, a double click edits it, and once '
            'the pile is fanned out you can drag a card to reorder it.',
      ),
      CatalogNote(
        'Touch',
        'A tap fans the pile out and keeps it open, and while two or more '
            'messages wait the gutter at the start turns into a collapse '
            'button. Each card shows its actions all the time on touch.',
      ),
      CatalogNote(
        'Keyboard',
        'Each card is its own tab stop, starting with the one at the front. '
            'Enter or F2 edits the card, Delete removes it, and Alt+Up and '
            'Alt+Down move it through the queue.',
      ),
      CatalogNote(
        'Motion',
        'The pile folds and fans out on the standard spring, and a message '
            'that lands behind a folded pile makes it recoil by 7 pixels on '
            'the gentle spring.',
      ),
      CatalogNote(
        'Do / Don’t',
        'Give the stack a bounded height and pass the transcript as its '
            'child, because it adds the pile’s height to the transcript’s '
            'bottom padding so the last message never ends up underneath '
            'it.',
      ),
    ],
    children: [_Pile()],
  );
}

typedef _Turn = ({
  CoilChatSender from,
  String text,
  List<DemoFile> files,
  bool seeded,
});

/// A chat with a reply in progress and three messages waiting.
class _Chat extends StatefulWidget {
  const _Chat();

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  /// How long the fake assistant takes to answer.
  static const _replyTime = Duration(seconds: 4);

  var _turns = <_Turn>[];
  var _queue = <CoilQueuedMessage>[];
  var _replying = false;
  var _paused = true;
  var _ids = 0;
  var _files = <DemoFile>[];
  Timer? _reply;
  final _composer = TextEditingController();

  /// The text and files of each queued message, by id.
  final _texts = <Object, String>{};
  final _queuedFiles = <Object, List<DemoFile>>{};

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void dispose() {
    _reply?.cancel();
    _composer.dispose();
    super.dispose();
  }

  /// A reply paused mid-thought with three messages waiting, so the pile
  /// reads at a glance.
  void _seed() {
    _reply?.cancel();
    _texts.clear();
    _queuedFiles.clear();
    _turns = [
      (
        from: CoilChatSender.user,
        text: 'Help me polish the dashboard design',
        files: const <DemoFile>[],
        seeded: true,
      ),
      (
        from: CoilChatSender.assistant,
        text:
            'Happy to. The spacing is uneven and a few labels are hard to '
            'read. Want me to go through it screen by screen?',
        files: const <DemoFile>[],
        seeded: true,
      ),
      (
        from: CoilChatSender.user,
        text: 'Yes, start with the overview screen',
        files: const <DemoFile>[],
        seeded: true,
      ),
    ];
    _queue = [
      _message('Fix spacing'),
      _message('Match the mockups'),
      _message('Audit the color contrast across the dashboard'),
    ];
    _replying = true;
    _paused = true;
  }

  CoilQueuedMessage _message(String text, [List<DemoFile> files = const []]) {
    final id = _ids++;
    _texts[id] = text;
    _queuedFiles[id] = files;
    return CoilQueuedMessage(
      id: id,
      child: Text(text),
      attachments: [
        for (final file in files)
          CoilFileThumbnail(name: file.name, image: file.image),
      ],
    );
  }

  /// The composer queues while a reply streams.
  void _queueMessage(String text) => setState(() {
    _queue = [..._queue, _message(text, _files)];
    _files = [];
  });

  void _send(String text, [List<DemoFile>? files]) {
    setState(() {
      _turns = [
        ..._turns,
        (
          from: CoilChatSender.user,
          text: text,
          files: files ?? _files,
          seeded: false,
        ),
      ];
      if (files == null) _files = [];
      _replying = true;
    });
    _schedule();
  }

  void _schedule() {
    _reply?.cancel();
    if (_paused) return;
    _reply = Timer(_replyTime, _answer);
  }

  /// Ends the reply (or stops it), then sends the front of the queue.
  void _answer({bool stopped = false}) {
    _reply?.cancel();
    final asked = _turns.lastWhere((t) => t.from == CoilChatSender.user);
    setState(() {
      _turns = [
        ..._turns,
        (
          from: CoilChatSender.assistant,
          text: stopped ? 'Stopped.' : 'Done with “${asked.text}”.',
          files: const <DemoFile>[],
          seeded: false,
        ),
      ];
      _replying = false;
      _paused = false;
    });
    if (_queue.isEmpty) return;
    final next = _queue.first;
    setState(() => _queue = _queue.sublist(1));
    _send(_texts.remove(next.id)!, _queuedFiles.remove(next.id));
  }

  void _edit(CoilQueuedMessage message) => setState(() {
    _composer.text = _texts.remove(message.id)!;
    _files = _queuedFiles.remove(message.id) ?? [];
    _queue = [
      for (final m in _queue)
        if (m.id != message.id) m,
    ];
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CoilButton(
          variant: CoilButtonVariant.secondary,
          size: CoilSize.compact,
          onPressed: () => setState(() {
            if (!_replying) {
              _seed();
              return;
            }
            _paused = !_paused;
            _schedule();
          }),
          child: Text(
            !_replying
                ? 'Start over'
                : _paused
                ? 'Resume reply'
                : 'Pause reply',
          ),
        ),
      ),
      SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Expanded(
              child: CoilQueuedStack(
                messages: _queue,
                onChanged: (queue) => setState(() => _queue = queue),
                onEdit: _edit,
                icon: const CatalogIcon(Glyph.cornerDownRight),
                editIcon: const CatalogIcon(Glyph.pencil),
                // The list keeps its last message clear of the pile
                // through the padding the stack hands it.
                child: ListView(
                  reverse: true,
                  children: [
                    if (_replying)
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CoilThinkingIndicator(
                          words: [
                            Text('Thinking'),
                            Text('Reading'),
                            Text('Drafting'),
                          ],
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
            ),
            CoilInputMessage(
              controller: _composer,
              placeholder: Text(
                _replying
                    ? 'Message the assistant to queue it'
                    : 'Message the assistant',
              ),
              status: _replying
                  ? CoilMessageStatus.streaming
                  : CoilMessageStatus.idle,
              onSend: _send,
              onQueue: _queueMessage,
              onStop: () => _answer(stopped: true),
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
              leading: CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                semanticLabel: 'Attach a file',
                icon: const CatalogIcon(Glyph.paperclip),
                onPressed: nextDemoFile(_files) == null
                    ? null
                    : () => setState(
                        () => _files = [..._files, nextDemoFile(_files)!],
                      ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The pile on its own, to see how it reads with one message, two or five.
class _Pile extends StatefulWidget {
  const _Pile();

  @override
  State<_Pile> createState() => _PileState();
}

class _PileState extends State<_Pile> {
  static const _texts = [
    'Fix spacing',
    'Match the mockups',
    'Check contrast on the charts',
    'Use tabular figures in tables',
    'Add an empty state',
  ];

  var _count = 3;
  late var _queue = _build(_count);

  static List<CoilQueuedMessage> _build(int count) => [
    for (var i = 0; i < count; i++)
      CoilQueuedMessage(
        id: _texts[i],
        child: Text(_texts[i]),
      ),
  ];

  @override
  Widget build(BuildContext context) => DemoSection(
    title: 'The pile on its own',
    description:
        'While the pile is folded, two cards peek 12 pixels out behind the '
        'front one and the rest fade away. Hover it to fan the whole queue '
        'into a list.',
    controls: DemoControls(
      children: [
        DemoControl.choice(
          label: 'Queued',
          value: _count,
          values: const [1, 2, 3, 5],
          labelOf: (v) => '$v',
          onChanged: (v) => setState(() {
            _count = v;
            _queue = _build(v);
          }),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CoilQueuedStack(
        messages: _queue,
        onChanged: (queue) => setState(() => _queue = queue),
        onEdit: (message) => setState(
          () => _queue = [
            for (final m in _queue)
              if (m.id != message.id) m,
          ],
        ),
        icon: const CatalogIcon(Glyph.cornerDownRight),
        editIcon: const CatalogIcon(Glyph.pencil),
      ),
    ),
  );
}
