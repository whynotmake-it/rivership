import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// An article with a comment thread in a sheet that opens halfway and drags
/// up to full height.
class DetentsDemo extends StatefulWidget {
  /// Creates the demo.
  const DetentsDemo({super.key});

  @override
  State<DetentsDemo> createState() => _DetentsDemoState();
}

class _DetentsDemoState extends State<DetentsDemo> {
  final _comments = ValueNotifier<List<_Comment>>(_seedComments);

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  void _openComments() {
    Navigator.of(context).push(
      DemoSheetRoute<void>(
        context: context,
        snappingConfig: const SheetSnappingConfig([0.5, 1.0], initialSnap: 0.5),
        // The sheet shrinks with its detent instead of sliding, so the
        // composer stays on screen at half height.
        dismissalMode: DismissalMode.shrink,
        child: _CommentsSheet(comments: _comments),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return DemoScaffold(
      title: const Text('Journal'),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: DemoContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Five days on the Kungsleden, Abisko to Nikkaluokta',
                  style: text.display,
                ),
              ),
              const SizedBox(height: 8),
              Text('Mara Lindqvist · 6 min read', style: text.muted.caption),
              const SizedBox(height: 20),
              for (final paragraph in _article) ...[
                Text(paragraph, style: text.body),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ValueListenableBuilder(
                  valueListenable: _comments,
                  builder: (context, comments, _) => CoilButton(
                    variant: CoilButtonVariant.secondary,
                    onPressed: _openComments,
                    child: Text('${comments.length} comments'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.comments});

  final ValueNotifier<List<_Comment>> comments;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _scroll = ScrollController();
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Typing needs room: the sheet opens to full height while the field has
  /// focus, and goes back to its two detents when it loses it, staying
  /// where it is until the next drag.
  void _onFocusChange() {
    final sheet = StupidSimpleSheetController.maybeOf<void>(context);
    if (_focus.hasFocus) {
      // `animateToComply` would pick the closest point of the new config,
      // and from half height that is the closed point, not full. Animate
      // to full explicitly instead.
      sheet
        ?..overrideSnappingConfig(SheetSnappingConfig.full)
        ..animateToRelative(1);
    } else {
      sheet?.overrideSnappingConfig(null);
    }
  }

  void _send() {
    final message = _field.text.trim();
    if (message.isEmpty) return;
    widget.comments.value = [
      ...widget.comments.value,
      _Comment(name: 'You', time: 'Now', text: message),
    ];
    _field.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll
          .animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
          // A lazy list refines its extent while it scrolls.
          .then((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CoilSheetPanel(
      title: const Text('Comments'),
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListenableBuilder(
          listenable: _field,
          builder: (context, _) => Row(
            spacing: 8,
            children: [
              Expanded(
                child: CoilInput(
                  controller: _field,
                  focusNode: _focus,
                  placeholder: const Text('Add a comment'),
                  semanticLabel: 'Comment',
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              CoilButton.icon(
                semanticLabel: 'Send',
                icon: const CoilIcon(CoilIconRole.send),
                onPressed: _field.text.trim().isEmpty ? null : _send,
              ),
            ],
          ),
        ),
      ),
      child: ValueListenableBuilder(
        valueListenable: widget.comments,
        builder: (context, comments, _) => ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          children: [
            for (final comment in comments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _CommentTile(comment: comment),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final _Comment comment;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.muted,
            shape: const CircleBorder(),
          ),
          child: SizedBox.square(
            dimension: 32,
            child: Center(
              child: Text(
                comment.initials,
                style: text.caption.copyWith(fontWeight: text.emphasis),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 8,
                children: [
                  Flexible(
                    child: Text(
                      comment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.body.copyWith(fontWeight: text.emphasis),
                    ),
                  ),
                  Text(comment.time, style: text.muted.caption),
                ],
              ),
              Text(comment.text, style: text.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _Comment {
  const _Comment({required this.name, required this.time, required this.text});

  final String name;
  final String time;
  final String text;

  String get initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join();
}

const _article = [
  'We left Abisko at nine in the morning with eleven kilos each and no plan '
      'beyond the huts. The first stretch follows the Abiskojåkka river '
      'through birch forest, flat enough to talk the whole way, and by '
      'Abiskojaure the trees had thinned to knee-high scrub.',
  'The second day is the long one. From Alesjaure the path climbs for hours '
      'over open tundra and the wind never quite stops. We crossed the '
      'Tjäktja pass in sleet, ate cold rice cakes in the shelter below the '
      'top and were at the hut by four, boots steaming by the stove.',
  'In late June the sun doesn’t set. At midnight the valley turned gold, '
      'then pink, and nobody bothered with the eye masks. We slept badly and '
      'didn’t mind.',
  'On the last morning Kebnekaise showed itself for the first time, and we '
      'walked the final stretch to Nikkaluokta without saying much. The bus '
      'to Kiruna leaves in the afternoon. Bring cash for the hut shops and a '
      'spare pair of dry socks.',
];

const _seedComments = [
  _Comment(
    name: 'Elin Sjöberg',
    time: 'Yesterday',
    text: 'Lovely write-up. Did you carry a stove or rely on the hut kitchens?',
  ),
  _Comment(
    name: 'Tobias Aalto',
    time: '5 h',
    text:
        'The Tjäktja pass in sleet sounds about right. Did the boots hold up?',
  ),
  _Comment(
    name: 'Mara Lindqvist',
    time: '4 h',
    text: 'Hut kitchens, mostly. We carried a small stove for the shelter day.',
  ),
  _Comment(
    name: 'Priya Raman',
    time: '3 h',
    text: 'How crowded were the huts in late June?',
  ),
  _Comment(
    name: 'Mara Lindqvist',
    time: '2 h',
    text: 'Busy at Sälka, quiet everywhere else. Book Sälka ahead if you can.',
  ),
  _Comment(
    name: 'Jonas Berg',
    time: '58 min',
    text: 'The midnight sun photos would have made this post perfect.',
  ),
  _Comment(
    name: 'Hanna Virtanen',
    time: '47 min',
    text: 'We did it south to north last year. The wind is worse that way.',
  ),
  _Comment(
    name: 'Leo Martin',
    time: '41 min',
    text: 'What did the bus to Kiruna cost? Planning for August.',
  ),
  _Comment(
    name: 'Mara Lindqvist',
    time: '38 min',
    text: 'Around 130 kronor when we went. Check the timetable before you go.',
  ),
  _Comment(
    name: 'Sofia Alves',
    time: '30 min',
    text: 'Eleven kilos for five days is impressive. What was in the pack?',
  ),
  _Comment(
    name: 'Nils Holm',
    time: '24 min',
    text: 'Did you see any reindeer? We met a herd just past Alesjaure.',
  ),
  _Comment(
    name: 'Amara Okafor',
    time: '19 min',
    text:
        'Saving this for next summer. Is the trail marked well enough to '
        'walk without a map?',
  ),
  _Comment(
    name: 'Mara Lindqvist',
    time: '12 min',
    text: 'It is, but we still carried one. Fog comes in fast on the pass.',
  ),
  _Comment(
    name: 'Erik Lund',
    time: '9 min',
    text: 'Any trouble with mosquitoes in the birch forest?',
  ),
  _Comment(
    name: 'Chloe Dubois',
    time: '7 min',
    text: 'Great photos. Which lens did you take?',
  ),
  _Comment(
    name: 'Mara Lindqvist',
    time: '5 min',
    text: 'Just the phone. The light does most of the work up there.',
  ),
  _Comment(
    name: 'Ravi Menon',
    time: '3 min',
    text: 'Is the hut shop at Kebnekaise worth the stop?',
  ),
  _Comment(
    name: 'Karin Ek',
    time: '1 min',
    text: 'Yes, the waffles alone. Bring cash like she says.',
  ),
];
