// The home page's tiles: small product surfaces, each composed of several
// live components, the way an app would use them together.
import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:coil_example/src/pages/components/accordion_page.dart';
import 'package:coil_example/src/pages/components/badge_page.dart';
import 'package:coil_example/src/pages/components/banner_page.dart';
import 'package:coil_example/src/pages/components/breadcrumb_page.dart';
import 'package:coil_example/src/pages/components/button_page.dart';
import 'package:coil_example/src/pages/components/calendar_page.dart';
import 'package:coil_example/src/pages/components/card_page.dart';
import 'package:coil_example/src/pages/components/carousel_dots_page.dart';
import 'package:coil_example/src/pages/components/chat_message_page.dart';
import 'package:coil_example/src/pages/components/checkbox_group_page.dart';
import 'package:coil_example/src/pages/components/data_table_page.dart';
import 'package:coil_example/src/pages/components/date_picker_page.dart';
import 'package:coil_example/src/pages/components/dropdown_page.dart';
import 'package:coil_example/src/pages/components/input_copy_page.dart';
import 'package:coil_example/src/pages/components/input_message_page.dart';
import 'package:coil_example/src/pages/components/queued_stack_page.dart';
import 'package:coil_example/src/pages/components/radio_group_page.dart';
import 'package:coil_example/src/pages/components/select_page.dart';
import 'package:coil_example/src/pages/components/slider_page.dart';
import 'package:coil_example/src/pages/components/switch_page.dart';
import 'package:coil_example/src/pages/components/textarea_page.dart';
import 'package:coil_example/src/pages/components/thinking_steps_page.dart';
import 'package:coil_example/src/pages/components/toggle_group_page.dart';
import 'package:coil_example/src/pages/components/tooltip_page.dart';
import 'package:coil_example/src/pages/home/bento.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// Every tile, in reading order.
final homeTiles = <BentoTileData>[
  BentoTileData(
    title: 'Agent chat',
    span: 2,
    links: const [
      chatMessageEntry,
      thinkingStepsEntry,
      queuedStackEntry,
      inputMessageEntry,
    ],
    builder: (_) => const AgentTile(),
  ),
  BentoTileData(
    title: 'Preferences',
    links: const [switchEntry, selectEntry, sliderEntry],
    builder: (_) => const PreferencesTile(),
  ),
  BentoTileData(
    title: 'Schedule',
    links: const [calendarEntry, datePickerEntry],
    builder: (_) => const ScheduleTile(),
  ),
  BentoTileData(
    title: 'Team',
    span: 2,
    links: const [dataTableEntry, badgeEntry],
    builder: (_) => const TeamTile(),
  ),
  BentoTileData(
    title: 'Release',
    links: const [buttonEntry, dropdownEntry, tooltipEntry],
    builder: (_) => const ReleaseTile(),
  ),
  BentoTileData(
    title: 'Editor',
    links: const [toggleGroupEntry, textareaEntry],
    builder: (_) => const EditorTile(),
  ),
  BentoTileData(
    title: 'Plan',
    links: const [radioGroupEntry, checkboxGroupEntry],
    builder: (_) => const PlanTile(),
  ),
  BentoTileData(
    title: 'Status',
    links: const [bannerEntry, accordionEntry],
    builder: (_) => const StatusTile(),
  ),
  BentoTileData(
    title: 'Share',
    links: const [breadcrumbEntry, inputCopyEntry, carouselDotsEntry],
    builder: (_) => const ShareTile(),
  ),
  BentoTileData(
    title: 'Projects',
    links: const [cardEntry],
    builder: (_) => const ProjectsTile(),
  ),
];

/// A tile's heading: what the surface is, in the muted caption style.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(text, style: style.muted.caption),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent chat

typedef _Turn = ({CoilChatSender from, String text, bool seeded});

const _plan = [
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.search),
    title: Text('Read the onboarding funnel'),
    sources: [Text('analytics'), Text('interviews.md')],
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.chart),
    title: Text('Found the drop-off'),
    detail: Text('Half of new teams stop at the invite step.'),
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.lightbulb),
    title: Text('Compared three fixes'),
    detail: Text('Kept the one with the fewest moving parts.'),
  ),
  CoilThinkingStep(
    leading: CatalogIcon(Glyph.pencil),
    title: Text('Drafted the plan'),
  ),
];

const _planReply =
    'Move the invite step after the first project, and let teams skip it. '
    'That keeps the funnel to three steps.';

/// An agent at work: its thinking streams in as steps, the reply follows,
/// and messages sent meanwhile wait in a queue you can fan out, reorder
/// and edit.
class AgentTile extends StatefulWidget {
  const AgentTile({super.key});

  @override
  State<AgentTile> createState() => _AgentTileState();
}

class _AgentTileState extends State<AgentTile> {
  static const _replyTime = Duration(milliseconds: 2400);

  final _composer = TextEditingController();
  final _copy = CoilCopyController();
  final _texts = <Object, String>{};
  var _ids = 0;

  var _turns = <_Turn>[
    (
      from: CoilChatSender.user,
      text: 'Plan the onboarding redesign',
      seeded: true,
    ),
  ];
  var _queue = <CoilQueuedMessage>[];
  var _streamed = 0;
  var _stepsExpanded = true;
  var _thought = false;
  var _replying = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _queue = [
      _message('Add a timeline'),
      _message('Draft the kickoff email'),
    ];
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_streamed < _plan.length) {
        setState(() => _streamed++);
        return;
      }
      timer.cancel();
      setState(() {
        _stepsExpanded = false;
        _thought = true;
        _turns = [
          ..._turns,
          (from: CoilChatSender.assistant, text: _planReply, seeded: false),
        ];
        _replying = false;
      });
      // Then the messages queued meanwhile go out, one after another.
      _timer = Timer(const Duration(milliseconds: 1600), _resume);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _composer.dispose();
    _copy.dispose();
    super.dispose();
  }

  CoilQueuedMessage _message(String text) {
    final id = _ids++;
    _texts[id] = text;
    return CoilQueuedMessage(id: id, semanticLabel: text, child: Text(text));
  }

  void _send(String text) {
    _timer?.cancel();
    setState(() {
      _turns = [
        ..._turns,
        (from: CoilChatSender.user, text: text, seeded: false),
      ];
      _replying = true;
    });
    _timer = Timer(_replyTime, _answer);
  }

  void _answer({bool stopped = false}) {
    _timer?.cancel();
    final asked = _turns.lastWhere((t) => t.from == CoilChatSender.user);
    setState(() {
      _turns = [
        ..._turns,
        (
          from: CoilChatSender.assistant,
          text: stopped ? 'Stopped.' : 'Done: ${asked.text.toLowerCase()}.',
          seeded: false,
        ),
      ];
      _replying = false;
    });
    if (_queue.isEmpty || stopped) return;
    final next = _queue.first;
    setState(() => _queue = _queue.sublist(1));
    _send(_texts.remove(next.id)!);
  }

  void _resume() {
    // The first reply is the plan; queued messages go after it.
    if (_replying || _queue.isEmpty) return;
    final next = _queue.first;
    setState(() => _queue = _queue.sublist(1));
    _send(_texts.remove(next.id)!);
  }

  @override
  Widget build(BuildContext context) {
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    final conversation = <Widget>[
      for (final (i, turn) in _turns.indexed) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CoilChatMessage(
            sender: turn.from,
            entrance: turn.seeded
                ? CoilChatMessageEntrance.none
                : CoilChatMessageEntrance.animated,
            actions: turn.text == _planReply
                ? [
                    CoilChatMessageAction(
                      label: const Text('Copy'),
                      semanticLabel: 'Copy',
                      icon: CoilCopyGlyph.listening(controller: _copy),
                      onPressed: () => _copy.copy(_planReply, context: context),
                    ),
                  ]
                : const [],
            child: Text(turn.text),
          ),
        ),
        // The agent's thinking, under the question it answers.
        if (i == 0 && _streamed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilThinkingSteps(
                label: Text(_thought ? 'Thought for 4 seconds' : 'Planning'),
                expanded: _stepsExpanded,
                onChanged: (v) => setState(() => _stepsExpanded = v),
                steps: _plan.take(_streamed).toList(),
              ),
            ),
          ),
      ],
      if (_replying && _thought)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: CoilThinkingIndicator(
              words: [Text('Thinking'), Text('Reading'), Text('Drafting')],
            ),
          ),
        ),
    ];
    return SizedBox(
      height: touch ? 480 : 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Expanded(
            child: CoilQueuedStack(
              messages: _queue,
              onChanged: (queue) => setState(() => _queue = queue),
              onEdit: (message) => setState(() {
                _composer.text = _texts.remove(message.id)!;
                _queue = [
                  for (final m in _queue)
                    if (m.id != message.id) m,
                ];
              }),
              icon: const CatalogIcon(Glyph.cornerDownRight),
              editIcon: const CatalogIcon(Glyph.pencil),
              child: ListView(
                // Its own scroll position, not the page's.
                primary: false,
                reverse: true,
                children: conversation.reversed.toList(),
              ),
            ),
          ),
          CoilInputMessage(
            controller: _composer,
            placeholder: Text(
              _replying ? 'Send to queue a message…' : 'Ask for a change…',
            ),
            status: _replying
                ? CoilMessageStatus.streaming
                : CoilMessageStatus.idle,
            onSend: (text) {
              if (_replying) {
                setState(() => _queue = [..._queue, _message(text)]);
              } else {
                _send(text);
              }
            },
            onQueue: (text) =>
                setState(() => _queue = [..._queue, _message(text)]),
            onStop: () {
              if (_thought) {
                _answer(stopped: true);
              } else {
                _timer?.cancel();
                setState(() {
                  _streamed = _plan.length;
                  _thought = true;
                  _stepsExpanded = false;
                  _replying = false;
                  _turns = [
                    ..._turns,
                    (
                      from: CoilChatSender.assistant,
                      text: 'Stopped.',
                      seeded: false,
                    ),
                  ];
                });
              }
            },
          ),
          if (!_replying && _queue.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CoilButton(
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                trailing: const CatalogIcon(Glyph.arrowRight),
                onPressed: _resume,
                child: Text(
                  _queue.length == 1
                      ? 'Send the queued message'
                      : 'Send ${_queue.length} queued messages',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preferences

/// App preferences: switch rows, a select and two sliders.
class PreferencesTile extends StatefulWidget {
  const PreferencesTile({super.key});

  @override
  State<PreferencesTile> createState() => _PreferencesTileState();
}

class _PreferencesTileState extends State<PreferencesTile> {
  var _notifications = true;
  var _autosave = false;
  var _sounds = true;
  var _digest = false;
  var _language = 'en';
  var _volume = 0.6;
  var _quality = 3.0;

  static const _languages = {
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'ja': '日本語',
  };

  static String _percent(double v) => '${(v * 100).round()} %';

  static String _qualityName(double v) => switch (v.round()) {
    1 => 'Draft',
    2 => 'Low',
    3 => 'Balanced',
    4 => 'High',
    _ => 'Best',
  };

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.tierOf(context) == CoilTier.touch ? 16.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Preferences'),
        CoilFieldGroup(
          children: [
            CoilSwitch(
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
              label: const Text('Notifications'),
            ),
            CoilSwitch(
              value: _autosave,
              onChanged: (v) => setState(() => _autosave = v),
              label: const Text('Auto-save drafts'),
            ),
            CoilSwitch(
              value: _sounds,
              onChanged: (v) => setState(() => _sounds = v),
              label: const Text('Sound effects'),
            ),
            CoilSwitch(
              value: _digest,
              onChanged: (v) => setState(() => _digest = v),
              label: const Text('Weekly digest'),
            ),
          ],
        ),
        SizedBox(height: gap),
        CoilField(
          label: const Text('Language'),
          child: CoilSelect<String>(
            value: _language,
            onChanged: (v) => setState(() => _language = v),
            options: [
              for (final MapEntry(:key, :value) in _languages.entries)
                CoilOption(value: key, label: Text(value), searchText: value),
            ],
          ),
        ),
        SizedBox(height: gap),
        CoilSlider(
          label: const Text('Volume'),
          value: _volume,
          valueBuilder: (_, v) => Text(_percent(v)),
          semanticFormatter: _percent,
          onChanged: (v) => setState(() => _volume = v),
        ),
        SizedBox(height: gap),
        CoilSlider(
          label: const Text('Quality'),
          variant: CoilSliderVariant.pips,
          min: 1,
          max: 5,
          divisions: 4,
          value: _quality,
          valueBuilder: (_, v) => Text(_qualityName(v)),
          semanticFormatter: _qualityName,
          onChanged: (v) => setState(() => _quality = v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule

/// A month to pick a day in, and a field that picks a date and time.
class ScheduleTile extends StatefulWidget {
  const ScheduleTile({super.key});

  @override
  State<ScheduleTile> createState() => _ScheduleTileState();
}

class _ScheduleTileState extends State<ScheduleTile> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime? _day = _firstWorkday();
  DateTime? _reminder;

  /// Today, or the next weekday: the calendar disables weekends.
  static DateTime _firstWorkday() {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    while (day.weekday >= DateTime.saturday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  /// A stand-in agenda: how many events a day holds.
  static int _events(DateTime day) => (day.day * 5 + day.month) % 4;

  static String _label(DateTime day) {
    final events = _events(day);
    final count = switch (events) {
      0 => 'No events',
      1 => '1 event',
      _ => '$events events',
    };
    return '${_weekdays[day.weekday - 1]} ${day.day} '
        '${_months[day.month - 1]} · $count';
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Schedule'),
        Center(
          child: CoilCalendar(
            selected: day,
            isDisabled: (day) => day.weekday >= DateTime.saturday,
            onSelected: (day) => setState(() => _day = day),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            day == null ? 'Pick a day to see its events' : _label(day),
            style: CoilTheme.textOf(context).muted.caption,
          ),
        ),
        const SizedBox(height: 12),
        CoilField(
          label: const Text('Reminder'),
          child: CoilDatePicker(
            value: _reminder,
            withTime: true,
            minuteInterval: 15,
            placeholder: const Text('No reminder'),
            onChanged: (v) => setState(() => _reminder = v),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Team

typedef _Member = ({
  String name,
  String role,
  CoilBadgeColor tone,
  String status,
  int commits,
});

/// A sortable, searchable, paged table of people, with badges.
class TeamTile extends StatefulWidget {
  const TeamTile({super.key});

  @override
  State<TeamTile> createState() => _TeamTileState();
}

class _TeamTileState extends State<TeamTile> {
  final _controller = CoilDataTableController<_Member>(
    pageSize: 6,
    matches: (m, query) => m.name.toLowerCase().contains(query),
    rows: [
      for (final (i, name) in const [
        'Ada Lovelace', 'Alan Turing', 'Barbara Liskov', 'Edsger Dijkstra', //
        'Frances Allen', 'Grace Hopper', 'Hedy Lamarr', 'Katherine Johnson',
        'Linus Torvalds', 'Margaret Hamilton',
      ].indexed)
        (
          name: name,
          role: const ['Engineer', 'Designer', 'Research'][i % 3],
          tone: const [
            CoilBadgeColor.green,
            CoilBadgeColor.green,
            CoilBadgeColor.amber,
            CoilBadgeColor.gray,
          ][i % 4],
          status: const ['Active', 'Active', 'Away', 'Offline'][i % 4],
          commits: (i * 37 + 12) % 200,
        ),
    ],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('Team'),
      CoilDataTable<_Member>(
        controller: _controller,
        columns: [
          CoilDataColumn(
            label: const Text('Name'),
            cellBuilder: (context, m) =>
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            compare: (a, b) => a.name.compareTo(b.name),
          ),
          CoilDataColumn(
            label: const Text('Role'),
            width: 120,
            cellBuilder: (context, m) => Text(m.role),
          ),
          CoilDataColumn(
            label: const Text('Status'),
            width: 112,
            cellBuilder: (context, m) => CoilBadge(
              variant: CoilBadgeVariant.dot,
              color: m.tone,
              child: Text(m.status),
            ),
          ),
          CoilDataColumn(
            label: const Text('Commits'),
            width: 104,
            alignment: AlignmentDirectional.centerEnd,
            cellBuilder: (context, m) => Text('${m.commits}'),
            compare: (a, b) => a.commits.compareTo(b.commits),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Release

/// A release's actions: publish with a loading state, a tooltip on an
/// icon button, and an action menu with a destructive item last.
class ReleaseTile extends StatefulWidget {
  const ReleaseTile({super.key});

  @override
  State<ReleaseTile> createState() => _ReleaseTileState();
}

class _ReleaseTileState extends State<ReleaseTile> {
  static const _changes = [
    ('New', 'A drawer sidebar on phones'),
    ('Improved', 'Sheets settle with a springier curve'),
    ('Fixed', 'Menus keep their scroll position'),
    ('Fixed', 'Arrow keys skip disabled days'),
  ];

  var _publishing = false;
  var _published = false;
  var _starred = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _publish() {
    setState(() => _publishing = true);
    _timer = Timer(const Duration(milliseconds: 1400), () {
      setState(() {
        _publishing = false;
        _published = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).buttonGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('Release'),
        Row(
          children: [
            Expanded(
              child: Text(
                'v2.4.0',
                style: text.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            CoilBadge(
              variant: CoilBadgeVariant.dot,
              color: _published ? CoilBadgeColor.green : CoilBadgeColor.amber,
              child: Text(_published ? 'Live' : 'Draft'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Springier sheets, a phone drawer and 12 fixes.',
          style: text.muted.body,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CoilButton(
              loading: _publishing,
              onPressed: _published ? null : _publish,
              child: Text(_published ? 'Published' : 'Publish'),
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () {},
              child: const Text('Preview'),
            ),
            CoilTooltip(
              message: Text(_starred ? 'Unstar' : 'Star'),
              child: CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                selected: _starred,
                semanticLabel: 'Star',
                icon: const CatalogIcon(Glyph.star),
                onPressed: () => setState(() => _starred = !_starred),
              ),
            ),
            CoilDropdown(
              entries: [
                CoilAction(
                  label: const Text('Duplicate'),
                  searchText: 'Duplicate',
                  leading: const CatalogIcon(Glyph.copy),
                  onPressed: () {},
                ),
                CoilAction(
                  label: const Text('Rename…'),
                  searchText: 'Rename',
                  leading: const CatalogIcon(Glyph.pencil),
                  onPressed: () {},
                ),
                CoilAction(
                  label: const Text('Download notes'),
                  searchText: 'Download notes',
                  leading: const CatalogIcon(Glyph.download),
                  onPressed: () {},
                ),
                const CoilMenuSeparator(),
                CoilAction(
                  label: const Text('Unpublish'),
                  searchText: 'Unpublish',
                  leading: const CatalogIcon(Glyph.trash),
                  tone: CoilActionTone.destructive,
                  onPressed: () => setState(() => _published = false),
                ),
              ],
              builder: (context, menu) => CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                semanticLabel: 'More actions',
                icon: const CatalogIcon(Glyph.more),
                onPressed: menu.open,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final (kind, change) in _changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CoilBadge(child: Text(kind)),
                  ),
                ),
                Expanded(child: Text(change, style: text.muted.body)),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Editor

/// The marks a note's text can carry, as bits of a character's style.
const _marks = {'bold': 1, 'italic': 2, 'underline': 4};

/// A text controller whose text carries bold, italic and underline marks.
///
/// It keeps one style per character, in step with every edit: typed text
/// takes the style of the character before it, or the style picked while
/// the caret was collapsed, and deleted text takes its style with it.
class _NoteController extends TextEditingController {
  _NoteController(List<(String, int)> segments)
    : _styles = [
        for (final (text, style) in segments)
          ...List.filled(text.length, style),
      ],
      super(text: segments.map((s) => s.$1).join());

  final List<int> _styles;

  /// The style the next typed character gets, when one was picked with a
  /// collapsed caret. Moving the caret forgets it.
  int? _typing;

  TextSelection get _range => selection.isValid
      ? selection
      : TextSelection.collapsed(offset: text.length);

  /// The marks at the caret, or the ones every selected character shares.
  int get active {
    final range = _range;
    if (range.isCollapsed) {
      final typing = _typing;
      if (typing != null) return typing;
      if (_styles.isEmpty) return 0;
      return _styles[range.start > 0 ? range.start - 1 : 0];
    }
    var shared = _marks.values.fold(0, (a, b) => a | b);
    for (var i = range.start; i < range.end; i++) {
      shared &= _styles[i];
    }
    return shared;
  }

  Set<String> get activeMarks => {
    for (final MapEntry(:key, :value) in _marks.entries)
      if (active & value != 0) key,
  };

  /// Makes the marks in [wanted] the active ones: on the selection, or on
  /// what is typed next when the caret is collapsed.
  void apply(Set<String> wanted) {
    final range = _range;
    final current = active;
    var next = current;
    for (final MapEntry(:key, :value) in _marks.entries) {
      next = wanted.contains(key) ? next | value : next & ~value;
    }
    if (next == current) return;
    if (range.isCollapsed) {
      _typing = next;
    } else {
      final changed = current ^ next;
      for (var i = range.start; i < range.end; i++) {
        _styles[i] = (_styles[i] & ~changed) | (next & changed);
      }
    }
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      _edit(newValue.text);
    } else if (newValue.selection != selection) {
      _typing = null;
    }
    super.value = newValue;
  }

  /// Finds what changed between the old text and [next], and gives the
  /// inserted characters their style.
  void _edit(String next) {
    final old = text;
    if (_styles.length != old.length) {
      _styles
        ..clear()
        ..addAll(List.filled(old.length, 0));
    }
    final shortest = math.min(old.length, next.length);
    var start = 0;
    while (start < shortest &&
        old.codeUnitAt(start) == next.codeUnitAt(start)) {
      start++;
    }
    var end = 0;
    while (end < shortest - start &&
        old.codeUnitAt(old.length - 1 - end) ==
            next.codeUnitAt(next.length - 1 - end)) {
      end++;
    }
    final removed = old.length - start - end;
    final added = next.length - start - end;
    final style =
        _typing ?? (_styles.isEmpty ? 0 : _styles[start > 0 ? start - 1 : 0]);
    _styles.replaceRange(start, start + removed, List.filled(added, style));
    if (added > 0) _typing = null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (_styles.length != text.length || text.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    final weight = CoilTheme.textOf(context).emphasis;
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i < text.length && _styles[i] == _styles[start]) continue;
      final marks = _styles[start];
      spans.add(
        TextSpan(
          text: text.substring(start, i),
          style: TextStyle(
            fontWeight: marks & 1 != 0 ? weight : null,
            fontStyle: marks & 2 != 0 ? FontStyle.italic : null,
            decoration: marks & 4 != 0 ? TextDecoration.underline : null,
          ),
        ),
      );
      start = i;
    }
    return TextSpan(style: style, children: spans);
  }
}

/// A note editor: the formatting toggles show the marks at the caret or
/// selection and change them, on the selection or on what is typed next.
class EditorTile extends StatefulWidget {
  const EditorTile({super.key});

  @override
  State<EditorTile> createState() => _EditorTileState();
}

class _EditorTileState extends State<EditorTile> {
  final _focus = FocusNode();
  final _note = _NoteController(const [
    ('Ship the ', 0),
    ('drawer', 1),
    (' on ', 0),
    ('Friday', 4),
    ('. Tighten the exits ', 0),
    ('first', 2),
    ('.', 0),
  ]);

  @override
  void dispose() {
    _focus.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _summary(String text) {
    final trimmed = text.trim();
    final words = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    if (words == 0) return 'Empty';
    final minutes = math.max(1, (words / 200).ceil());
    return '$words ${words == 1 ? 'word' : 'words'} · $minutes min read';
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return ListenableBuilder(
      listenable: _note,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('Note'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CoilToggleGroup<String>(
                values: _note.activeMarks,
                onChanged: (values) {
                  _note.apply(values);
                  // Pressing a toggle must not end the editing.
                  _focus.requestFocus();
                },
                options: const [
                  CoilOption(
                    value: 'bold',
                    label: CatalogIcon(Glyph.bold, semanticLabel: 'Bold'),
                  ),
                  CoilOption(
                    value: 'italic',
                    label: CatalogIcon(Glyph.italic, semanticLabel: 'Italic'),
                  ),
                  CoilOption(
                    value: 'underline',
                    label: CatalogIcon(
                      Glyph.underline,
                      semanticLabel: 'Underline',
                    ),
                  ),
                ],
              ),
              Text(_summary(_note.text), style: text.muted.caption),
            ],
          ),
          const SizedBox(height: 12),
          CoilInput.multiline(
            controller: _note,
            focusNode: _focus,
            minLines: 7,
            placeholder: const Text('Write a note…'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan

/// Picking a plan and its add-ons: one highlight glides between the rows,
/// and neighboring selections merge into one block.
class PlanTile extends StatefulWidget {
  const PlanTile({super.key});

  @override
  State<PlanTile> createState() => _PlanTileState();
}

class _PlanTileState extends State<PlanTile> {
  var _plan = 'team';
  var _addOns = <String>{'sso', 'audit'};

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('Plan'),
      CoilRadioGroup<String>(
        value: _plan,
        onChanged: (v) => setState(() => _plan = v),
        semanticLabel: 'Plan',
        options: const [
          CoilOption(value: 'starter', label: Text('Starter, free')),
          CoilOption(value: 'team', label: Text('Team, €12 a seat')),
          CoilOption(value: 'scale', label: Text('Scale, talk to us')),
        ],
      ),
      const SizedBox(height: 16),
      const _Eyebrow('Add-ons'),
      CoilCheckboxGroup<String>(
        values: _addOns,
        onChanged: (v) => setState(() => _addOns = v),
        semanticLabel: 'Add-ons',
        options: const [
          CoilOption(value: 'sso', label: Text('Single sign-on')),
          CoilOption(value: 'audit', label: Text('Audit log')),
          CoilOption(value: 'support', label: Text('Priority support')),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Status

/// A deploy's status: a banner you can dismiss and bring back, over
/// answers that open one at a time.
class StatusTile extends StatefulWidget {
  const StatusTile({super.key});

  @override
  State<StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<StatusTile> {
  var _shown = true;
  String? _open = 'rollback';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('Status'),
      if (_shown)
        CoilBanner(
          status: CoilBannerStatus.success,
          title: const Text('Deployed to production'),
          description: const Text('v2.4.0 is live in all regions.'),
          onDismissRequested: () => setState(() => _shown = false),
        )
      else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CoilButton(
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            onPressed: () => setState(() => _shown = true),
            child: const Text('Show the banner'),
          ),
        ),
      const SizedBox(height: 12),
      CoilAccordion<String>.single(
        value: _open,
        onChanged: (v) => setState(() => _open = v),
        items: const [
          CoilAccordionItem(
            value: 'rollback',
            label: Text('Can I roll back?'),
            panel: Text('Yes, any release from the last 30 days.'),
          ),
          CoilAccordionItem(
            value: 'downtime',
            label: Text('Was there downtime?'),
            panel: Text('No. Traffic moved over one region at a time.'),
          ),
          CoilAccordionItem(
            value: 'notify',
            label: Text('Who was notified?'),
            panel: Text('Everyone watching the project.'),
          ),
          CoilAccordionItem(
            value: 'schedule',
            label: Text('Can I schedule a release?'),
            panel: Text('Yes, pick a time when you publish.'),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Share

/// Sharing a page: where it lives, a link to copy, and dots to page
/// through its previews.
class ShareTile extends StatefulWidget {
  const ShareTile({super.key});

  @override
  State<ShareTile> createState() => _ShareTileState();
}

class _ShareTileState extends State<ShareTile> {
  var _slide = 0;

  /// The deck's slides: a title, and how the photo is cropped for it.
  static const _slides = [
    ('Kickoff', 1.0, Alignment.center),
    ('Timeline', 1.7, Alignment.bottomLeft),
    ('Metrics', 1.4, Alignment.topRight),
    ('Team', 2.0, Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final (title, scale, alignment) = _slides[_slide];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Share'),
        CoilBreadcrumb(
          crumbs: [
            CoilCrumb(label: const Text('Projects'), onPressed: () {}),
            CoilCrumb(label: const Text('Onboarding'), onPressed: () {}),
            const CoilCrumb(label: Text('Kickoff deck')),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Slide ${_slide + 1} of ${_slides.length}: $title',
          image: true,
          child: Container(
            height: 168,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(
                  CoilTheme.radiiOf(context).container,
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: Transform.scale(
                    scale: scale,
                    alignment: alignment,
                    child: Image.asset(
                      'assets/images/dunes.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x99000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: ExcludeSemantics(
                    child: Text(
                      title,
                      style: text.body.copyWith(
                        color: const Color(0xFFFFFFFF),
                        fontWeight: text.emphasis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: CoilCarouselDots(
            count: _slides.length,
            value: _slide,
            onChanged: (v) => setState(() => _slide = v),
          ),
        ),
        const SizedBox(height: 8),
        const CoilInputCopy(value: 'https://coil.dev/s/kickoff'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Projects

/// Cards in a group: pressable rows with an icon, one you can dismiss.
class ProjectsTile extends StatefulWidget {
  const ProjectsTile({super.key});

  @override
  State<ProjectsTile> createState() => _ProjectsTileState();
}

class _ProjectsTileState extends State<ProjectsTile> {
  var _tipShown = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('Projects'),
      CoilCardGroup(
        children: [
          CoilCard(
            icon: const CatalogIcon(Glyph.zap),
            title: const Text('Onboarding'),
            description: const Text('3 tasks due this week'),
            onPressed: () {},
          ),
          CoilCard(
            icon: const CatalogIcon(Glyph.chart),
            title: const Text('Growth report'),
            description: const Text('Updated 2 hours ago'),
            onPressed: () {},
          ),
        ],
      ),
      if (_tipShown) ...[
        const SizedBox(height: 12),
        CoilCard(
          icon: const CatalogIcon(Glyph.lightbulb),
          title: const Text('Tip'),
          description: const Text('Search finds any page: ⌘K or Ctrl K.'),
          onDismissed: () => setState(() => _tipShown = false),
        ),
      ],
    ],
  );
}
