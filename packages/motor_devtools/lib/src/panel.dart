import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/motion_editor.dart';
import 'package:motor_devtools/src/naming.dart';
import 'package:motor_devtools/src/session.dart';
import 'package:motor_devtools/src/style.dart';
import 'package:motor_devtools/src/timeline.dart';

/// What a controller is doing right now.
enum PlaybackState {
  /// Its ticker runs.
  playing,

  /// It has a plan left to play but its ticker is stopped.
  paused,

  /// Nothing left to play.
  idle;

  /// The state of [controller].
  static PlaybackState of(TrackController controller) {
    if (controller.isAnimating) return playing;
    final tracks = controller.inspectPlayback().tracks;
    return tracks.any((track) => track.currentStepIndex >= 0) ? paused : idle;
  }

  /// The combined state of [controllers].
  static PlaybackState ofAll(Iterable<TrackController> controllers) {
    final states = controllers.map(of).toSet();
    if (states.contains(playing)) return playing;
    return states.contains(paused) ? paused : idle;
  }

  /// A short description.
  String get label => switch (this) {
    playing => 'Playing',
    paused => 'Paused',
    idle => 'Idle',
  };
}

/// Speed and motions shared by an inspection group, applied to current and
/// future members.
class GroupSettings {
  /// The members' playback speed, or null to leave theirs.
  double? speed;

  /// Motions by track `debugLabel`; the null key applies to all tracks.
  final overrides = <String?, Motion>{};
}

/// What the panel needs from the tools.
abstract interface class PanelHost {
  /// Every live controller, oldest first.
  List<TrackController> get controllers;

  /// Motions registered by the app, by name.
  Map<String, Motion> get appMotions;

  /// A controller's display name, numbered among others with its name.
  String nameOf(TrackController controller);

  /// A controller's name without the number.
  String baseNameOf(TrackController controller);

  /// Whether [controller] has never played.
  bool isIdle(TrackController controller);

  /// Increases each time [controller] plays a frame.
  int lastActive(TrackController controller);

  /// The shared settings of [group].
  GroupSettings settingsOf(String group);

  /// Changes one controller's speed.
  void setSpeed(TrackController controller, double speed);

  /// Changes one controller's track motion, or restores it with null.
  void setOverride(TrackController controller, Track<Object> track, Motion? m);

  /// Changes a group's speed for current and future members.
  void setGroupSpeed(String group, double speed);

  /// Changes a group's motion for tracks labeled [label] (null: all).
  void setGroupOverride(String group, String? label, Motion? motion);

  /// Shows [controller].
  void showController(TrackController controller);

  /// Shows [group].
  void showGroup(String group);

  /// Goes back one page.
  void back();

  /// Collapses the panel.
  void close();
}

/// The panel's pages: the controller list, a group, and a controller.
class DevToolsPanel extends StatefulWidget {
  /// Creates the panel.
  const DevToolsPanel({
    required this.host,
    required this.group,
    required this.controller,
    super.key,
  });

  /// The tools' state.
  final PanelHost host;

  /// The group shown, if any.
  final String? group;

  /// The controller shown, if any.
  final TrackController? controller;

  @override
  State<DevToolsPanel> createState() => _DevToolsPanelState();
}

@immutable
class _Page {
  const _Page(this.group, this.controller);

  final String? group;
  final TrackController? controller;

  @override
  bool operator ==(Object other) =>
      other is _Page &&
      other.group == group &&
      identical(other.controller, controller);

  @override
  int get hashCode => Object.hash(group, controller);
}

class _DevToolsPanelState extends State<DevToolsPanel> {
  var _pages = const [_Page(null, null)];

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final wanted = [
      const _Page(null, null),
      if (widget.group case final group?) _Page(group, null),
      if (widget.controller case final controller?)
        _Page(widget.group, controller),
    ];
    final isPop =
        wanted.length < _pages.length &&
        [
          for (var i = 0; i < wanted.length; i++) _pages[i] == wanted[i],
        ].every((same) => same);
    if (!isPop) _pages = wanted;
    _pages = [
      for (final page in _pages)
        if (page.controller == null ||
            host.controllers.contains(page.controller))
          page,
    ];
    final depth = (wanted.length - 1).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) => SingleMotionBuilder(
        value: depth,
        motion: const Motion.smoothSpring(
          duration: Duration(milliseconds: 380),
        ),
        debugLabel: internalDebugLabel,
        builder: (context, t, _) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              for (final (index, page) in _pages.indexed)
                if ((index - t).abs() < 0.999)
                  _placed(index - t, width, index == depth, page),
            ],
          );
        },
      ),
    );
  }

  Widget _placed(double offset, double width, bool current, _Page page) {
    final host = widget.host;
    final Widget child;
    if (page.controller case final controller?) {
      child = _ControllerDetail(
        key: ObjectKey(controller),
        host: host,
        controller: controller,
      );
    } else if (page.group case final group?) {
      child = _GroupDetail(key: ValueKey(group), host: host, group: group);
    } else {
      child = _ControllerList(host: host);
    }
    return IgnorePointer(
      ignoring: !current,
      child: Opacity(
        opacity: offset < 0
            ? (1 + offset).clamp(0.0, 1.0)
            : ((1 - offset) * 1.5).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(width * (offset < 0 ? offset * 0.2 : offset), 0),
          child: child,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Container(
      height: 60,
      color: palette.surface,
      padding: EdgeInsets.only(left: onBack == null ? 18 : 10, right: 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            GlyphButton(
              Glyph.back,
              key: const ValueKey('motor-devtools-back'),
              onTap: onBack,
              semanticLabel: 'Back',
              size: 30,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.title,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.caption,
                ),
              ],
            ),
          ),
          GlyphButton(
            Glyph.close,
            key: const ValueKey('motor-devtools-close'),
            onTap: onClose,
            semanticLabel: 'Close Motor devtools',
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _ControllerList extends StatefulWidget {
  const _ControllerList({required this.host});

  final PanelHost host;

  @override
  State<_ControllerList> createState() => _ControllerListState();
}

class _ControllerListState extends State<_ControllerList> {
  final _openRows = <String>{};
  var _idleOpen = false;
  var _hiddenOpen = false;

  /// Rows for [controllers]: explicit groups first, then one row per name,
  /// merging controllers that share it.
  List<Widget> _rows(List<TrackController> controllers, {bool groups = true}) {
    final host = widget.host;
    final byGroup = <String, List<TrackController>>{};
    final byName = <String, List<TrackController>>{};
    for (final controller in controllers) {
      if (controller.inspectionGroup case final group? when groups) {
        (byGroup[group] ??= []).add(controller);
      } else {
        (byName[host.baseNameOf(controller)] ??= []).add(controller);
      }
    }
    return [
      for (final MapEntry(key: group, value: members) in byGroup.entries)
        _GroupRow(
          key: ValueKey('motor-group-$group'),
          name: group,
          members: members,
          onTap: () => host.showGroup(group),
        ),
      for (final MapEntry(key: name, value: members) in byName.entries)
        if (members.length == 1)
          _ControllerRow(
            key: ObjectKey(members.single),
            controller: members.single,
            name: host.nameOf(members.single),
            onTap: () => host.showController(members.single),
          )
        else ...[
          _GroupRow(
            key: ValueKey('motor-same-$name'),
            name: name,
            members: members,
            open: _openRows.contains(name),
            onTap: () => setState(
              () => _openRows.contains(name)
                  ? _openRows.remove(name)
                  : _openRows.add(name),
            ),
          ),
          Disclosure(
            open: _openRows.contains(name),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  for (final member in members)
                    _ControllerRow(
                      key: ObjectKey(member),
                      controller: member,
                      name: host.nameOf(member),
                      onTap: () => host.showController(member),
                    ),
                ],
              ),
            ),
          ),
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final host = widget.host;
    final visible = [
      for (final controller in host.controllers)
        if (controller.inspectable) controller,
    ];
    final hidden = [
      for (final controller in host.controllers)
        if (!controller.inspectable) controller,
    ];
    final idle = [
      for (final controller in visible)
        if (controller.inspectionGroup == null && host.isIdle(controller))
          controller,
    ];
    final shown = [
      for (final controller in visible)
        if (!idle.contains(controller)) controller,
    ];
    final count = visible.length;
    return ColoredBox(
      color: palette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: 'Motor',
            subtitle: count == 1 ? '1 controller' : '$count controllers',
            onClose: host.close,
          ),
          const Hairline(),
          Flexible(
            child: host.controllers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No controllers yet', style: palette.body),
                        const SizedBox(height: 6),
                        Text(
                          'Controllers show up here as soon as they are '
                          'created.',
                          textAlign: TextAlign.center,
                          style: palette.caption,
                        ),
                      ],
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      ..._rows(shown),
                      if (idle.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: DisclosureRow(
                            key: const ValueKey('motor-devtools-idle'),
                            title: '${idle.length} idle',
                            trailing: 'never played',
                            open: _idleOpen,
                            onTap: () => setState(() => _idleOpen = !_idleOpen),
                          ),
                        ),
                        Disclosure(
                          open: _idleOpen,
                          child: Column(children: _rows(idle)),
                        ),
                      ],
                      if (hidden.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: DisclosureRow(
                            key: const ValueKey('motor-devtools-hidden'),
                            title: '${hidden.length} hidden',
                            trailing: _hiddenOpen ? 'Hide' : 'Show',
                            open: _hiddenOpen,
                            onTap: () =>
                                setState(() => _hiddenOpen = !_hiddenOpen),
                          ),
                        ),
                        Disclosure(
                          open: _hiddenOpen,
                          child: Opacity(
                            opacity: 0.6,
                            child: Column(
                              children: _rows(hidden, groups: false),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A row that enters with a short rise and fade.
class _RowEntrance extends StatelessWidget {
  const _RowEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    from: 0,
    value: 1,
    motion: const Motion.smoothSpring(duration: Duration(milliseconds: 420)),
    debugLabel: internalDebugLabel,
    builder: (context, t, child) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
    ),
    child: child,
  );
}

class _RowLayout extends StatelessWidget {
  const _RowLayout({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.lane,
    required this.trailing,
  });

  final PlaybackState state;
  final String title;
  final String subtitle;
  final PlaybackSnapshot? lane;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
      child: Row(
        children: [
          _StatusDot(state),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.body,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (lane case final lane?)
            SizedBox(width: 56, height: 6, child: SummaryLane(snapshot: lane)),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _ControllerRow extends StatelessWidget {
  const _ControllerRow({
    required this.controller,
    required this.name,
    required this.onTap,
    super.key,
  });

  final TrackController controller;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return _RowEntrance(
      child: Pressable(
        key: ValueKey('motor-controller-$name'),
        onTap: onTap,
        semanticLabel: name,
        pressedScale: 0.98,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final state = PlaybackState.of(controller);
            return _RowLayout(
              state: state,
              title: name,
              subtitle: '${state.label}  ·  ${_trackSummary(controller)}',
              lane: controller.inspectPlayback(),
              trailing: GlyphIcon(Glyph.forward, color: palette.tertiary),
            );
          },
        ),
      ),
    );
  }
}

/// One row for several controllers: an explicit group, which opens on tap,
/// or controllers sharing a name, which unfold in place ([open] non-null).
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.name,
    required this.members,
    required this.onTap,
    this.open,
    super.key,
  });

  final String name;
  final List<TrackController> members;
  final VoidCallback onTap;
  final bool? open;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final title = '$name ×${members.length}';
    return _RowEntrance(
      child: Pressable(
        key: ValueKey('motor-group-row-$name'),
        onTap: onTap,
        semanticLabel: title,
        pressedScale: 0.98,
        child: ListenableBuilder(
          listenable: Listenable.merge(members),
          builder: (context, _) {
            final state = PlaybackState.ofAll(members);
            final playing = members.where((c) => c.isAnimating).length;
            return _RowLayout(
              state: state,
              title: title,
              subtitle: switch (playing) {
                0 => '${state.label}  ·  ${_trackSummary(members.first)}',
                _ => '$playing playing  ·  ${_trackSummary(members.first)}',
              },
              lane: null,
              trailing: open == null
                  ? GlyphIcon(Glyph.forward, color: palette.tertiary)
                  : SingleMotionBuilder(
                      value: open! ? 0.25 : 0,
                      motion: foldMotion,
                      debugLabel: internalDebugLabel,
                      builder: (context, turns, child) => Transform.rotate(
                        angle: turns * 6.283185307179586,
                        child: child,
                      ),
                      child: GlyphIcon(Glyph.forward, color: palette.tertiary),
                    ),
            );
          },
        ),
      ),
    );
  }
}

String _trackSummary(TrackController controller) {
  final tracks = controller.inspectPlayback().tracks;
  final labels = [
    for (final playback in tracks)
      if (playback.track.debugLabel case final label?) label,
  ];
  if (labels.isEmpty) {
    return switch (tracks.length) {
      0 => 'No tracks yet',
      1 => '1 track',
      final count => '$count tracks',
    };
  }
  final more = tracks.length - 2;
  return [...labels.take(2), if (more > 0) '+$more'].join(', ');
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.state);

  final PlaybackState state;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          PlaybackState.playing => palette.accent,
          PlaybackState.paused => null,
          PlaybackState.idle => palette.tertiary.withValues(alpha: 0.5),
        },
        border: state == PlaybackState.paused
            ? Border.all(color: palette.accent, width: 1.5)
            : null,
      ),
    );
  }
}

const _speeds = [0.1, 0.25, 0.5, 1.0];

String _nameIn(List<(Track<Object>, String)> tracks, Track<Object> track) =>
    tracks.firstWhere((entry) => identical(entry.$1, track)).$2;

String _speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.round() : speed}×';

String _motionSummary(Map<String, Motion> appMotions, Motion? motion) {
  final name = appMotions.entries
      .where((entry) => entry.value == motion)
      .firstOrNull
      ?.key;
  return switch (motion) {
    null => 'authored',
    _ when name != null => name,
    CupertinoMotion(:final duration, :final bounce) =>
      'spring ${formatDuration(duration)}, ${bounce.toStringAsFixed(2)}',
    CurvedMotion(:final duration) => 'curve ${formatDuration(duration)}',
    _ => 'custom',
  };
}

/// Play/pause, replay and speed.
class _Transport extends StatelessWidget {
  const _Transport({
    required this.state,
    required this.speed,
    required this.onPlayPause,
    required this.onReplay,
    required this.onSpeed,
  });

  final PlaybackState state;
  final double? speed;
  final VoidCallback onPlayPause;
  final VoidCallback? onReplay;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    final playing = state == PlaybackState.playing;
    return Row(
      children: [
        GlyphButton(
          playing ? Glyph.pause : Glyph.play,
          key: const ValueKey('motor-devtools-play-pause'),
          onTap: onPlayPause,
          semanticLabel: playing ? 'Pause' : 'Play',
          filled: true,
          size: 34,
        ),
        const SizedBox(width: 8),
        GlyphButton(
          Glyph.replay,
          key: const ValueKey('motor-devtools-replay'),
          onTap: onReplay,
          semanticLabel: 'Replay',
          size: 34,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Segmented<double>(
            options: _speeds,
            selected: _speeds.contains(speed) ? speed : null,
            labelOf: _speedLabel,
            keyOf: (speed) => ValueKey('motor-devtools-speed-$speed'),
            onSelected: onSpeed,
          ),
        ),
      ],
    );
  }
}

/// A folded "Motion" section around a [MotionEditor].
class _MotionSection<K> extends StatefulWidget {
  const _MotionSection({
    required this.summary,
    required this.editor,
  });

  final String summary;
  final MotionEditor<K> editor;

  @override
  State<_MotionSection<K>> createState() => _MotionSectionState<K>();
}

class _MotionSectionState<K> extends State<_MotionSection<K>> {
  var _open = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      const Hairline(),
      DisclosureRow(
        key: const ValueKey('motor-devtools-motion'),
        title: 'Motion',
        trailing: widget.summary,
        open: _open,
        onTap: () => setState(() => _open = !_open),
      ),
      Disclosure(
        open: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: widget.editor,
        ),
      ),
    ],
  );
}

class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.host, required this.group, super.key});

  final PanelHost host;
  final String group;

  List<TrackController> get _members => [
    for (final controller in host.controllers)
      if (controller.inspectionGroup == group && controller.inspectable)
        controller,
  ]..sort((a, b) => host.lastActive(b).compareTo(host.lastActive(a)));

  void _playPause(List<TrackController> members) {
    final playing = members.where((c) => c.isAnimating).toList();
    if (playing.isNotEmpty) {
      for (final member in playing) {
        member.pause();
      }
      return;
    }
    for (final member in members) {
      member.resume();
    }
    if (!members.any((c) => c.isAnimating)) _replay(members);
  }

  void _replay(List<TrackController> members) {
    for (final member in members) {
      member.replay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final members = _members;
    final settings = host.settingsOf(group);
    return ColoredBox(
      color: palette.surface,
      child: ListenableBuilder(
        listenable: Listenable.merge(members),
        builder: (context, _) {
          final state = PlaybackState.ofAll(members);
          final labels = {
            for (final member in members)
              for (final playback in member.inspectPlayback().tracks)
                if (playback.track.debugLabel case final label?) label,
          };
          final tracks = <(String?, String)>[
            (null, 'All tracks'),
            for (final label in labels) (label, label),
          ];
          final editing = settings.overrides.keys
              .where((key) => key == null || labels.contains(key))
              .firstOrNull;
          return _GroupEditor(
            host: host,
            group: group,
            header: _Header(
              title: '$group ×${members.length}',
              subtitle: '${state.label}  ·  group',
              onBack: host.back,
              onClose: host.close,
            ),
            transport: _Transport(
              state: state,
              speed: settings.speed ?? 1,
              onPlayPause: () => _playPause(members),
              onReplay: members.any((c) => c.inspectPlayback().plans.isNotEmpty)
                  ? () => _replay(members)
                  : null,
              onSpeed: (speed) => host.setGroupSpeed(group, speed),
            ),
            tracks: tracks,
            initialTrack: editing,
            settings: settings,
            members: [
              for (final member in members)
                _ControllerRow(
                  key: ObjectKey(member),
                  controller: member,
                  name: host.nameOf(member),
                  onTap: () => host.showController(member),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({
    required this.host,
    required this.group,
    required this.header,
    required this.transport,
    required this.tracks,
    required this.initialTrack,
    required this.settings,
    required this.members,
  });

  final PanelHost host;
  final String group;
  final Widget header;
  final Widget transport;
  final List<(String?, String)> tracks;
  final String? initialTrack;
  final GroupSettings settings;
  final List<Widget> members;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late String? _track = widget.initialTrack;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final track = widget.tracks.any((t) => t.$1 == _track) ? _track : null;
    final overrides = widget.settings.overrides;
    final name = widget.tracks.firstWhere((t) => t.$1 == track).$2;
    final appMotions = widget.host.appMotions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header,
        const Hairline(),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.transport,
                    _MotionSection<String?>(
                      summary:
                          '$name · '
                          '${_motionSummary(appMotions, overrides[track])}',
                      editor: MotionEditor<String?>(
                        tracks: widget.tracks,
                        track: track,
                        current: overrides[track],
                        tuned: overrides.keys.toSet(),
                        appMotions: widget.host.appMotions,
                        onTrackSelected: (track) =>
                            setState(() => _track = track),
                        onChanged: (motion) {
                          widget.host.setGroupOverride(
                            widget.group,
                            track,
                            motion,
                          );
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Hairline(),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text('Members', style: palette.label),
                    ),
                  ],
                ),
              ),
              ...widget.members,
            ],
          ),
        ),
      ],
    );
  }
}

class _ControllerDetail extends StatefulWidget {
  const _ControllerDetail({
    required this.host,
    required this.controller,
    super.key,
  });

  final PanelHost host;
  final TrackController controller;

  @override
  State<_ControllerDetail> createState() => _ControllerDetailState();
}

class _ControllerDetailState extends State<_ControllerDetail> {
  Track<Object>? _selectedTrack;

  void _togglePlayback() {
    final controller = widget.controller;
    if (controller.isAnimating) {
      controller.pause();
      return;
    }
    controller.resume();
    if (!controller.isAnimating) controller.replay();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final host = widget.host;
    final controller = widget.controller;
    return ColoredBox(
      color: palette.surface,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = PlaybackState.of(controller);
          final tracks = [
            for (final (index, playback)
                in controller.inspectPlayback().tracks.indexed)
              (
                playback.track,
                playback.track.debugLabel ?? guessTrackName(playback, index),
              ),
          ];
          if (!tracks.any((entry) => identical(entry.$1, _selectedTrack))) {
            _selectedTrack = tracks.firstOrNull?.$1;
          }
          final overrides = controller.motionOverrides;
          final speed = controller.playbackSpeed;
          final group = controller.inspectionGroup;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: host.nameOf(controller),
                subtitle: [
                  state.label,
                  if (speed != 1) _speedLabel(speed),
                  if (group != null) 'in $group',
                ].join('  ·  '),
                onBack: host.back,
                onClose: host.close,
              ),
              const Hairline(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  children: [
                    _Transport(
                      state: state,
                      speed: speed,
                      onPlayPause: _togglePlayback,
                      onReplay: controller.inspectPlayback().plans.isEmpty
                          ? null
                          : controller.replay,
                      onSpeed: (speed) => host.setSpeed(controller, speed),
                    ),
                    const SizedBox(height: 18),
                    Timeline(
                      key: const ValueKey('motor-devtools-full-timeline'),
                      controller: controller,
                      selectedTrack: _selectedTrack,
                    ),
                    if (_selectedTrack case final track?)
                      _MotionSection<Track<Object>>(
                        summary:
                            '${_nameIn(tracks, track)} · ${_motionSummary(
                              host.appMotions,
                              overrides[track],
                            )}',
                        editor: MotionEditor<Track<Object>>(
                          tracks: tracks,
                          track: track,
                          current: overrides[track],
                          tuned: overrides.keys.toSet(),
                          appMotions: host.appMotions,
                          onTrackSelected: (track) =>
                              setState(() => _selectedTrack = track),
                          onChanged: (motion) =>
                              host.setOverride(controller, track, motion),
                        ),
                      ),
                    if (controller.debugLabel == null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.fill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Pass debugLabel to the controller or its builder '
                          'to name it.',
                          style: palette.caption,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
