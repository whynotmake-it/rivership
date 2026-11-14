import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

const queuedStackEntry = CatalogEntry(
  slug: 'queued-stack',
  title: 'QueuedStack',
  group: CatalogGroup.shellAndComposites,
  summary: 'Messages sent during a reply wait in a pile above the composer.',
  page: QueuedStackPage.new,
);

typedef _Turn = ({CoilChatSender from, String text, bool seeded});

class QueuedStackPage extends StatefulWidget {
  const QueuedStackPage({super.key});

  @override
  State<QueuedStackPage> createState() => _QueuedStackPageState();
}

class _QueuedStackPageState extends State<QueuedStackPage> {
  /// How long the fake assistant takes to answer.
  static const _replyTime = Duration(seconds: 4);

  var _turns = <_Turn>[];
  var _queue = <CoilQueuedMessage>[];
  var _replying = false;
  var _paused = true;
  var _ids = 0;
  Timer? _reply;
  final _composer = TextEditingController();

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
    _turns = [
      (
        from: CoilChatSender.user,
        text: 'Help me polish the dashboard design',
        seeded: true,
      ),
    ];
    _queue = [
      _message('Tighten the spacing'),
      _message('Match the mockups'),
      _message(
        'Audit the color contrast across the dashboard and suggest '
        'accessible token values',
      ),
    ];
    _replying = true;
    _paused = true;
  }

  /// The text of each queued message, by id, for sending and editing.
  final _texts = <Object, String>{};

  CoilQueuedMessage _message(String text) {
    final id = _ids++;
    _texts[id] = text;
    return CoilQueuedMessage(id: id, semanticLabel: text, child: Text(text));
  }

  void _send(String text) {
    // While a reply streams, a new message waits its turn.
    if (_replying) {
      setState(() => _queue = [..._queue, _message(text)]);
      return;
    }
    setState(() {
      _turns = [..._turns, (from: .user, text: text, seeded: false)];
      _replying = true;
    });
    _schedule();
  }

  void _schedule() {
    _reply?.cancel();
    if (_paused) return;
    _reply = Timer(_replyTime, _answer);
  }

  /// Ends the reply, then sends the front of the queue.
  void _answer() {
    final asked = _turns.lastWhere((t) => t.from == CoilChatSender.user);
    setState(() {
      _turns = [
        ..._turns,
        (
          from: .assistant,
          text: 'Done with “${asked.text}”.',
          seeded: false,
        ),
      ];
      _replying = false;
    });
    if (_queue.isEmpty) return;
    final next = _queue.first;
    setState(() => _queue = _queue.sublist(1));
    _send(_texts.remove(next.id)!);
  }

  void _edit(CoilQueuedMessage message) => setState(() {
    _composer.text = _texts.remove(message.id)!;
    _queue = [
      for (final m in _queue)
        if (m.id != message.id) m,
    ];
  });

  @override
  Widget build(BuildContext context) {
    final stackPadding = CoilQueuedStack.collapsedHeightOf(
      context,
      _queue.length,
    );
    return CatalogPage(
      title: 'QueuedStack',
      summary:
          'Send while the assistant replies to queue a message. Hover the '
          'pile, or tap it on touch, to fan it out, then drag to reorder.',
      children: [
        DemoSection(
          title: 'With InputMessage',
          child: DemoColumn(
            children: [
              CoilButton(
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
                      ? 'Reset'
                      : _paused
                      ? 'Resume reply'
                      : 'Pause reply',
                ),
              ),
              SizedBox(
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ListView(
                            reverse: true,
                            padding: EdgeInsets.only(
                              bottom: stackPadding == 0 ? 0 : stackPadding + 8,
                            ),
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
                                    child: Text(turn.text),
                                  ),
                                ),
                            ],
                          ),
                          PositionedDirectional(
                            start: 0,
                            end: 0,
                            bottom: 0,
                            child: CoilQueuedStack(
                              messages: _queue,
                              onChanged: (queue) =>
                                  setState(() => _queue = queue),
                              onEdit: _edit,
                              icon: const CatalogIcon(Glyph.cornerDownRight),
                              editIcon: const CatalogIcon(Glyph.pencil),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CoilInputMessage(
                      controller: _composer,
                      placeholder: _replying
                          ? 'Send while I’m replying to queue a message…'
                          : 'Message…',
                      onSend: _send,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
