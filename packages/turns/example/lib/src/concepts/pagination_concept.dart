import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/scroll.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/concepts/visible_items.dart';
import 'package:turns_example/src/shell/turns_playground.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// A chat that opens in the middle of 400 messages on a fake server and
/// pages in both directions as you scroll, with the loaded range, the page
/// in flight and the visible window drawn on a rail beside it.
class PaginationConcept extends StatefulWidget {
  const PaginationConcept({super.key});

  @override
  State<PaginationConcept> createState() => _PaginationConceptState();
}

const _total = 400;
const _deepLink = 200;

enum _OpenAt { deepLink, latest }

class _PaginationConceptState extends State<PaginationConcept> {
  var _openAt = _OpenAt.deepLink;
  var _pageSize = 40;
  var _latency = 400;
  var _trigger = 600;

  var _generation = 0;
  var _controller = TurnScrollController();
  late int _lo;
  late int _hi;
  var _loadingOlder = false;
  var _loadingNewer = false;
  var _requests = 0;
  final _log = <({bool up, String text})>[];
  final _timers = <Timer>[];

  final _viewportKey = GlobalKey();
  final _visible = VisibleItems();

  final _code = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _open();
    _visible.attach(_viewportKey);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _controller.dispose();
    _visible.dispose();
    _code.dispose();
    super.dispose();
  }

  void _open() {
    switch (_openAt) {
      case _OpenAt.deepLink:
        _lo = _deepLink - _pageSize ~/ 2;
        _hi = _lo + _pageSize;
      case _OpenAt.latest:
        _lo = _total - _pageSize;
        _hi = _total;
    }
    _loadingOlder = false;
    _loadingNewer = false;
    _requests = 0;
    _log.clear();
    _updateCode();
  }

  void _restart() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    final old = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    setState(() {
      _generation++;
      _controller = TurnScrollController();
      _open();
    });
  }

  void _updateCode() {
    final open = _openAt == _OpenAt.deepLink
        ? "  initialItemId: 'm$_deepLink', // O(1): nothing above it is built\n"
        : '  // opens at the bottom\n';
    _code.value =
        'NotificationListener<TurnScrollNotification>(\n'
        '  onNotification: (n) {\n'
        '    // Prepending never moves what is on screen.\n'
        '    if (n.leadingExtent < $_trigger) loadOlder();\n'
        '    if (n.trailingExtent < $_trigger) loadNewer();\n'
        '    return false;\n'
        '  },\n'
        '  child: TurnScrollView(\n'
        '  $open'
        '    leadingSlivers: [if (hasOlder) OlderSkeleton()],\n'
        '    tailSliver: hasNewer ? NewerSkeleton() : null,\n'
        '    ...\n'
        '  ),\n'
        ');';
  }

  void _note({required bool up, required String text}) {
    _log.insert(0, (up: up, text: text));
    if (_log.length > 5) _log.removeLast();
  }

  bool _onScroll(TurnScrollNotification n) {
    _consider(leading: n.leadingExtent, trailing: n.trailingExtent);
    return false;
  }

  void _consider({required double leading, required double trailing}) {
    if (leading < _trigger && _lo > 0 && !_loadingOlder) {
      _fetch(up: true, distance: leading);
    }
    if (trailing < _trigger && _hi < _total && !_loadingNewer) {
      _fetch(up: false, distance: trailing);
    }
  }

  /// After a page lands, the edge may still be within the trigger, as when
  /// a short page doesn't fill the view: check again without waiting for
  /// the next scroll.
  void _recheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final pos = _controller.position;
      if (!pos.hasContentDimensions) return;
      _consider(
        leading: pos.pixels - pos.minScrollExtent,
        trailing: pos.maxScrollExtent - pos.pixels,
      );
    });
  }

  void _fetch({required bool up, required double distance}) {
    final from = up ? math.max(0, _lo - _pageSize) : _hi;
    final to = up ? _lo : math.min(_total, _hi + _pageSize);
    final generation = _generation;
    setState(() {
      if (up) {
        _loadingOlder = true;
      } else {
        _loadingNewer = true;
      }
      _requests++;
      _note(
        up: up,
        text:
            '${distance.round()} px left ${up ? 'above' : 'below'} '
            '→ fetch #$from–#${to - 1}',
      );
    });
    late final Timer timer;
    timer = Timer(Duration(milliseconds: _latency), () {
      _timers.remove(timer);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (up) {
          _lo = from;
          _loadingOlder = false;
        } else {
          _hi = to;
          _loadingNewer = false;
        }
        _note(
          up: up,
          text: up
              ? '${to - from} prepended above · on-screen shift 0 px'
              : '${to - from} appended below',
        );
      });
      _recheck();
    });
    _timers.add(timer);
  }

  Widget _settings() {
    Widget sized(Widget child) => SizedBox(width: 196, child: child);
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        sized(
          PlaygroundChoice<_OpenAt>(
            label: 'Open at',
            value: _openAt,
            options: const {
              _OpenAt.deepLink: 'Message #$_deepLink',
              _OpenAt.latest: 'Latest',
            },
            onChanged: (v) {
              _openAt = v;
              _restart();
            },
          ),
        ),
        sized(
          PlaygroundChoice<int>(
            label: 'Page size',
            value: _pageSize,
            options: const {10: '10', 40: '40', 100: '100'},
            onChanged: (v) {
              _pageSize = v;
              _restart();
            },
          ),
        ),
        sized(
          PlaygroundChoice<int>(
            label: 'Server latency',
            value: _latency,
            options: const {0: 'None', 400: '0.4 s', 1500: '1.5 s'},
            onChanged: (v) => setState(() => _latency = v),
          ),
        ),
        sized(
          PlaygroundChoice<int>(
            label: 'Load when within',
            value: _trigger,
            options: const {200: '200', 600: '600', 1500: '1500 px'},
            onChanged: (v) => setState(() {
              _trigger = v;
              _updateCode();
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final chat = NotificationListener<TurnScrollNotification>(
      onNotification: _onScroll,
      child: KeyedSubtree(
        key: _viewportKey,
        child: TurnScrollView<Object>(
          key: ValueKey(_generation),
          controller: _controller,
          itemCount: _hi - _lo,
          itemId: (i) => _lo + i,
          initialItemId: _openAt == _OpenAt.deepLink ? _deepLink : null,
          initialAlignment: 0.4,
          itemSpacing: 6,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          leadingSlivers: [
            if (_lo > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  child: _EdgeSkeleton(loading: _loadingOlder, above: true),
                ),
              )
            else
              const SliverToBoxAdapter(child: _StartOfHistory()),
          ],
          tailSliver: _hi < _total
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _EdgeSkeleton(loading: _loadingNewer, above: false),
                  ),
                )
              : null,
          itemBuilder: (context, i) {
            final index = _lo + i;
            return _visible.wrap(
              index,
              _Message(index: index, deepLinked: index == _deepLink),
            );
          },
        ),
      ),
    );

    return ConceptPage(
      routeName: turnsPaginationRouteName,
      lead:
          'The chat opens on message #$_deepLink of $_total without building '
          'anything above it. Scroll either way: when fewer than '
          '$_trigger px are left, the next page is fetched, and '
          'older pages land above you without moving a pixel. The rail shows '
          'what is loaded, what is in flight, and where you are.',
      controls: _settings(),
      stage: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: chat),
          SizedBox(width: 1, child: ColoredBox(color: colors.border)),
          SizedBox(
            width: 92,
            child: ValueListenableBuilder(
              valueListenable: _visible,
              builder: (context, visible, _) => _HistoryRail(
                lo: _lo,
                hi: _hi,
                olderInFlight: _loadingOlder
                    ? (math.max(0, _lo - _pageSize), _lo)
                    : null,
                newerInFlight: _loadingNewer
                    ? (_hi, math.min(_total, _hi + _pageSize))
                    : null,
                visible: visible,
              ),
            ),
          ),
        ],
      ),
      stageHeight: 480,
      readout: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          ValueListenableBuilder(
            valueListenable: _visible,
            builder: (context, visible, _) => ConceptStats(
              children: [
                ConceptStat(
                  label: 'Loaded',
                  value: '${_hi - _lo} of $_total',
                ),
                ConceptStat(label: 'Requests', value: '$_requests'),
                ConceptStat(
                  label: 'On screen',
                  value: visible == null
                      ? '–'
                      : '#${visible.$1}–#${visible.$2}',
                  tone: ConceptTone.good,
                ),
              ],
            ),
          ),
          _Log(entries: _log),
        ],
      ),
      code: _code,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.index, required this.deepLinked});

  final int index;
  final bool deepLinked;

  static const _lines = [
    'Did the deploy go out?',
    'Yes, all green. Watching the error rate for a bit.',
    'Can someone review the pagination PR?',
    'On it after lunch.',
    'Reminder: retro at 4.',
    'The new onboarding copy is so much shorter, love it.',
    'Pushing a fix for the flaky test now.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final mine = index % 3 == 0;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: deepLinked
                ? colors.brandWash
                : mine
                ? colors.muted
                : colors.background,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: deepLinked ? colors.brandMark : colors.border,
                width: deepLinked ? 1.5 : 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: deepLinked ? '#$index · linked  ' : '#$index  ',
                    style: text.muted.micro.tabular,
                  ),
                  TextSpan(
                    text: _lines[index % _lines.length],
                    style: text.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows at an edge with more history behind it; they shimmer
/// while a page is in flight.
class _EdgeSkeleton extends StatelessWidget {
  const _EdgeSkeleton({required this.loading, required this.above});

  final bool loading;
  final bool above;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final rows = [
      for (final (i, width) in const [180.0, 240.0, 140.0].indexed)
        Align(
          alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
          child: Opacity(
            opacity: loading ? 1 : 0.45,
            child: CoilSkeleton(width: width, height: 30),
          ),
        ),
    ];
    final label = Text(
      loading
          ? 'Loading ${above ? 'older' : 'newer'} messages…'
          : 'More ${above ? 'above' : 'below'}',
      style: text.muted.micro,
      textAlign: TextAlign.center,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: above ? [...rows, label] : [label, ...rows],
    );
  }
}

class _StartOfHistory extends StatelessWidget {
  const _StartOfHistory();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      'Start of the conversation',
      textAlign: TextAlign.center,
      style: CoilTheme.textOf(context).muted.micro,
    ),
  );
}

/// The whole history on the server, top to bottom, with what is loaded,
/// what is in flight and what is on screen.
class _HistoryRail extends StatelessWidget {
  const _HistoryRail({
    required this.lo,
    required this.hi,
    required this.olderInFlight,
    required this.newerInFlight,
    required this.visible,
  });

  final int lo;
  final int hi;
  final (int, int)? olderInFlight;
  final (int, int)? newerInFlight;
  final (int, int)? visible;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        children: [
          Text('#0', style: text.muted.micro.tabular),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _RailPainter(
                lo: lo,
                hi: hi,
                olderInFlight: olderInFlight,
                newerInFlight: newerInFlight,
                visible: visible,
                track: colors.muted,
                loaded: colors.brandWash,
                loadedEdge: colors.brandMark,
                window: colors.brandFill,
                inFlight: colors.mutedForeground,
                labelStyle: text.micro.tabular.copyWith(
                  color: colors.brandInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('#${_total - 1}', style: text.muted.micro.tabular),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.lo,
    required this.hi,
    required this.olderInFlight,
    required this.newerInFlight,
    required this.visible,
    required this.track,
    required this.loaded,
    required this.loadedEdge,
    required this.window,
    required this.inFlight,
    required this.labelStyle,
  });

  final int lo;
  final int hi;
  final (int, int)? olderInFlight;
  final (int, int)? newerInFlight;
  final (int, int)? visible;
  final Color track;
  final Color loaded;
  final Color loadedEdge;
  final Color window;
  final Color inFlight;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 14.0;
    const left = 2.0;
    double y(int index) => size.height * index / _total;
    Rect span(int from, int to, {double inset = 0}) => Rect.fromLTRB(
      left + inset,
      y(from),
      left + barWidth - inset,
      math.max(y(to), y(from) + 2),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barWidth, size.height),
        const Radius.circular(7),
      ),
      Paint()..color = track,
    );
    final loadedRect = span(lo, hi);
    canvas
      ..drawRect(loadedRect, Paint()..color = loaded)
      ..drawRect(
        loadedRect,
        Paint()
          ..color = loadedEdge
          ..style = PaintingStyle.stroke,
      );
    for (final flight in [olderInFlight, newerInFlight]) {
      if (flight == null) continue;
      final rect = span(flight.$1, flight.$2);
      canvas
        ..save()
        ..clipRect(rect);
      final hatch = Paint()
        ..color = inFlight.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var x = rect.top - barWidth; x < rect.bottom; x += 4) {
        canvas.drawLine(
          Offset(rect.left, x + barWidth),
          Offset(rect.right, x),
          hatch,
        );
      }
      canvas.restore();
    }
    if (visible case final visible?) {
      final rect = span(visible.$1, visible.$2 + 1, inset: -3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = window,
      );
      final label = TextPainter(
        text: TextSpan(text: '#${visible.$1}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          left + barWidth + 6,
          (rect.center.dy - label.height / 2).clamp(
            0,
            size.height - label.height,
          ),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.lo != lo ||
      old.hi != hi ||
      old.olderInFlight != olderInFlight ||
      old.newerInFlight != newerInFlight ||
      old.visible != visible ||
      old.track != track ||
      old.window != window;
}

class _Log extends StatelessWidget {
  const _Log({required this.entries});

  final List<({bool up, String text})> entries;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final mono = text.micro.copyWith(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const ['monospace'],
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaces[1],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(CoilTheme.radiiOf(context).item),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Text('Requests, newest first', style: text.muted.micro),
            if (entries.isEmpty)
              Text('Scroll the chat to fetch a page.', style: mono)
            else
              for (final entry in entries)
                Row(
                  children: [
                    Icon(
                      entry.up ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                      size: 12,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.text,
                        style: mono,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
