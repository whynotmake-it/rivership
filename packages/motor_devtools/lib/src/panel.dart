import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
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

  /// A short description.
  String get label => switch (this) {
    playing => 'Playing',
    paused => 'Paused',
    idle => 'Idle',
  };
}

/// The panel's pages: the controller list and a controller's detail.
class DevToolsPanel extends StatefulWidget {
  /// Creates the panel.
  const DevToolsPanel({
    required this.controllers,
    required this.selected,
    required this.nameOf,
    required this.onSelect,
    required this.onBack,
    required this.onClose,
    required this.onSpeedChanged,
    required this.onOverrideChanged,
    super.key,
  });

  /// The live controllers, oldest first.
  final List<TrackController> controllers;

  /// The controller shown in detail, if any.
  final TrackController? selected;

  /// The display name of a controller.
  final String Function(TrackController controller) nameOf;

  /// Shows a controller's detail.
  final ValueChanged<TrackController> onSelect;

  /// Returns to the list.
  final VoidCallback onBack;

  /// Collapses the panel.
  final VoidCallback onClose;

  /// Changes a controller's playback speed.
  final void Function(TrackController controller, double speed) onSpeedChanged;

  /// Overrides a track's motion, or restores it when the motion is null.
  final void Function(
    TrackController controller,
    Track<Object> track,
    Motion? motion,
  )
  onOverrideChanged;

  @override
  State<DevToolsPanel> createState() => _DevToolsPanelState();
}

class _DevToolsPanelState extends State<DevToolsPanel> {
  TrackController? _detail;

  @override
  Widget build(BuildContext context) {
    if (widget.selected != null) _detail = widget.selected;
    if (_detail != null && !widget.controllers.contains(_detail)) {
      _detail = null;
    }
    final detail = _detail;
    final showingDetail = widget.selected != null;
    return LayoutBuilder(
      builder: (context, constraints) => SingleMotionBuilder(
        value: showingDetail ? 1 : 0,
        motion: const Motion.smoothSpring(
          duration: Duration(milliseconds: 380),
        ),
        debugLabel: internalDebugLabel,
        builder: (context, t, _) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              if (t < 0.999)
                IgnorePointer(
                  ignoring: showingDetail,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(-width * 0.2 * t, 0),
                      child: _ControllerList(
                        controllers: widget.controllers,
                        nameOf: widget.nameOf,
                        onSelect: widget.onSelect,
                        onClose: widget.onClose,
                      ),
                    ),
                  ),
                ),
              if (detail != null && t > 0.001)
                IgnorePointer(
                  ignoring: !showingDetail,
                  child: Opacity(
                    opacity: (t * 1.5).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(width * (1 - t), 0),
                      child: _ControllerDetail(
                        key: ObjectKey(detail),
                        controller: detail,
                        name: widget.nameOf(detail),
                        onBack: widget.onBack,
                        onClose: widget.onClose,
                        onSpeedChanged: (speed) =>
                            widget.onSpeedChanged(detail, speed),
                        onOverrideChanged: (track, motion) =>
                            widget.onOverrideChanged(detail, track, motion),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
              semanticLabel: 'All controllers',
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

class _ControllerList extends StatelessWidget {
  const _ControllerList({
    required this.controllers,
    required this.nameOf,
    required this.onSelect,
    required this.onClose,
  });

  final List<TrackController> controllers;
  final String Function(TrackController controller) nameOf;
  final ValueChanged<TrackController> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final count = controllers.length;
    return ColoredBox(
      color: palette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: 'Motor',
            subtitle: count == 1 ? '1 controller' : '$count controllers',
            onClose: onClose,
          ),
          const Hairline(),
          Flexible(
            child: controllers.isEmpty
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
                      for (final controller in controllers)
                        _ControllerRow(
                          key: ObjectKey(controller),
                          controller: controller,
                          name: nameOf(controller),
                          onTap: () => onSelect(controller),
                        ),
                    ],
                  ),
          ),
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
    return SingleMotionBuilder(
      from: 0,
      value: 1,
      motion: const Motion.smoothSpring(duration: Duration(milliseconds: 420)),
      debugLabel: internalDebugLabel,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Pressable(
        key: ValueKey('motor-controller-$name'),
        onTap: onTap,
        semanticLabel: name,
        pressedScale: 0.98,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final state = PlaybackState.of(controller);
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
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: palette.body,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.label}  ·  ${_trackSummary(controller)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: palette.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlyphIcon(Glyph.forward, color: palette.tertiary),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _trackSummary(TrackController controller) {
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
    return [
      ...labels.take(2),
      if (more > 0) '+$more',
    ].join(', ');
  }
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

class _ControllerDetail extends StatefulWidget {
  const _ControllerDetail({
    required this.controller,
    required this.name,
    required this.onBack,
    required this.onClose,
    required this.onSpeedChanged,
    required this.onOverrideChanged,
    super.key,
  });

  final TrackController controller;
  final String name;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<double> onSpeedChanged;
  final void Function(Track<Object> track, Motion? motion) onOverrideChanged;

  @override
  State<_ControllerDetail> createState() => _ControllerDetailState();
}

class _ControllerDetailState extends State<_ControllerDetail> {
  static const _speeds = [0.1, 0.25, 0.5, 1.0];

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
    final controller = widget.controller;
    return ColoredBox(
      color: palette.surface,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = PlaybackState.of(controller);
          final tracks = [
            for (final playback in controller.inspectPlayback().tracks)
              playback.track,
          ];
          if (!tracks.contains(_selectedTrack)) {
            _selectedTrack = tracks.firstOrNull;
          }
          final speed = controller.playbackSpeed;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: widget.name,
                subtitle: speed == 1
                    ? state.label
                    : '${state.label}  ·  ${_speedLabel(speed)}',
                onBack: widget.onBack,
                onClose: widget.onClose,
              ),
              const Hairline(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  children: [
                    Row(
                      children: [
                        GlyphButton(
                          state == PlaybackState.playing
                              ? Glyph.pause
                              : Glyph.play,
                          key: const ValueKey('motor-devtools-play-pause'),
                          onTap: _togglePlayback,
                          semanticLabel: state == PlaybackState.playing
                              ? 'Pause'
                              : 'Play',
                          filled: true,
                          size: 34,
                        ),
                        const SizedBox(width: 8),
                        GlyphButton(
                          Glyph.replay,
                          key: const ValueKey('motor-devtools-replay'),
                          onTap: controller.inspectPlayback().plans.isEmpty
                              ? null
                              : controller.replay,
                          semanticLabel: 'Replay',
                          size: 34,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Segmented<double>(
                            options: _speeds,
                            selected: _speeds.contains(speed) ? speed : null,
                            labelOf: _speedLabel,
                            keyOf: (speed) =>
                                ValueKey('motor-devtools-speed-$speed'),
                            onSelected: widget.onSpeedChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Timeline(
                      key: const ValueKey('motor-devtools-full-timeline'),
                      controller: controller,
                      selectedTrack: _selectedTrack,
                    ),
                    if (_selectedTrack case final track?) ...[
                      const SizedBox(height: 22),
                      const Hairline(),
                      const SizedBox(height: 16),
                      _MotionEditor(
                        tracks: tracks,
                        track: track,
                        current: controller.motionOverrides[track],
                        overridden: controller.motionOverrides.keys.toSet(),
                        onTrackSelected: (track) =>
                            setState(() => _selectedTrack = track),
                        onChanged: (motion) =>
                            widget.onOverrideChanged(track, motion),
                      ),
                    ],
                    if (controller.debugLabel == null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.fill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Name this controller by passing debugLabel to it '
                          'or to its builder.',
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

  static String _speedLabel(double speed) =>
      '${speed == speed.roundToDouble() ? speed.round() : speed}×';
}

enum _MotionKind {
  authored('Authored'),
  spring('Spring'),
  ease('Ease'),
  linear('Linear');

  const _MotionKind(this.label);

  final String label;

  static _MotionKind of(Motion? motion) => switch (motion) {
    null => authored,
    CupertinoMotion() => spring,
    LinearMotion() => linear,
    _ => ease,
  };
}

class _MotionEditor extends StatefulWidget {
  const _MotionEditor({
    required this.tracks,
    required this.track,
    required this.current,
    required this.overridden,
    required this.onTrackSelected,
    required this.onChanged,
  });

  final List<Track<Object>> tracks;
  final Track<Object> track;
  final Motion? current;
  final Set<Track<Object>> overridden;
  final ValueChanged<Track<Object>> onTrackSelected;
  final ValueChanged<Motion?> onChanged;

  @override
  State<_MotionEditor> createState() => _MotionEditorState();
}

class _MotionEditorState extends State<_MotionEditor> {
  double? _draftDuration;
  double? _draftBounce;

  double get _duration =>
      _draftDuration ??
      switch (widget.current) {
        CupertinoMotion(:final duration) ||
        CurvedMotion(:final duration) => duration.inMilliseconds.toDouble(),
        _ => 500,
      };

  double get _bounce =>
      _draftBounce ??
      switch (widget.current) {
        CupertinoMotion(:final bounce) => bounce,
        _ => 0.15,
      };

  Motion? _motion(_MotionKind kind) {
    final duration = Duration(milliseconds: _duration.round());
    return switch (kind) {
      _MotionKind.authored => null,
      _MotionKind.spring => Motion.cupertino(
        duration: duration,
        bounce: _bounce,
      ),
      _MotionKind.ease => Motion.curved(duration, Curves.easeInOutCubic),
      _MotionKind.linear => Motion.linear(duration),
    };
  }

  void _apply(_MotionKind kind) {
    widget.onChanged(_motion(kind));
    setState(() => _draftDuration = _draftBounce = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final kind = _MotionKind.of(widget.current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Motion', style: palette.label),
        const SizedBox(height: 4),
        Text(
          'Try another motion for a track. Changes replay the latest plan '
          'and last for this session.',
          style: palette.caption,
        ),
        if (widget.tracks.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (index, track) in widget.tracks.indexed)
                _TrackChip(
                  label: track.debugLabel ?? 'Track ${index + 1}',
                  selected: identical(track, widget.track),
                  tuned: widget.overridden.contains(track),
                  onTap: () => widget.onTrackSelected(track),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Segmented<_MotionKind>(
          options: _MotionKind.values,
          selected: kind,
          labelOf: (kind) => kind.label,
          keyOf: (kind) => ValueKey('motor-devtools-motion-${kind.name}'),
          onSelected: _apply,
        ),
        if (kind != _MotionKind.authored) ...[
          const SizedBox(height: 10),
          ValueSlider(
            key: const ValueKey('motor-devtools-duration'),
            label: 'Duration',
            valueLabel: '${_duration.round()} ms',
            value: _duration,
            min: 100,
            max: 1500,
            onChanged: (value) =>
                setState(() => _draftDuration = (value / 10).round() * 10),
            onChangeEnd: () => _apply(kind),
          ),
        ],
        if (kind == _MotionKind.spring)
          ValueSlider(
            key: const ValueKey('motor-devtools-bounce'),
            label: 'Bounce',
            valueLabel: _bounce.toStringAsFixed(2),
            value: _bounce,
            min: 0,
            max: 0.6,
            onChanged: (value) =>
                setState(() => _draftBounce = (value * 100).round() / 100),
            onChangeEnd: () => _apply(kind),
          ),
      ],
    );
  }
}

class _TrackChip extends StatelessWidget {
  const _TrackChip({
    required this.label,
    required this.selected,
    required this.tuned,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool tuned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.text : palette.fill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tuned) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: palette.caption.copyWith(
                color: selected ? palette.surface : palette.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
