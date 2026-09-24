import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/motion_editor.dart';
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

  /// Changes one controller's track motion, or restores it with null, and
  /// replays its latest plan unless [replay] is false.
  void setOverride(
    TrackController controller,
    Track<Object> track,
    Motion? motion, {
    bool replay = true,
  });

  /// What the tools changed on [controller], such as `Paused` or `0.25×`;
  /// empty when nothing is changed.
  List<String> changesOf(TrackController controller);

  /// Resumes [controller] and restores its speed and its own motions.
  void reset(TrackController controller);

  /// Clears [group]'s shared settings and resumes its members.
  void resetGroup(String group);

  /// Undoes every change made with the tools.
  void resetAll();

  /// Changes a group's speed for current and future members.
  void setGroupSpeed(String group, double speed);

  /// Changes a group's motion for tracks labeled [label] (null: all).
  void setGroupOverride(
    String group,
    String? label,
    Motion? motion, {
    bool replay = true,
  });

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

  /// The depth the slide animates to. It follows the wanted depth one frame
  /// late, so a new page is built and measured before the slide starts.
  var _depth = 0;

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
    final depth = wanted.length - 1;
    if (depth != _depth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _depth != depth) setState(() => _depth = depth);
      });
    }
    return SingleMotionBuilder(
      value: _depth.toDouble(),
      motion: const Motion.smoothSpring(duration: Duration(milliseconds: 300)),
      debugLabel: internalDebugLabel,
      builder: (context, t, _) => _PageStack(
        children: [
          for (final (index, page) in _pages.indexed)
            if ((index - t).abs() < 0.99 || index == depth || index == _depth)
              _PagePosition(
                key: ValueKey(page),
                offset: index - t,
                child: IgnorePointer(
                  ignoring: index != depth,
                  child: _pageFor(page),
                ),
              ),
        ],
      ),
    );
  }

  Widget _pageFor(_Page page) {
    final host = widget.host;
    if (page.controller case final controller?) {
      return _ControllerDetail(host: host, controller: controller);
    }
    if (page.group case final group?) {
      return _GroupDetail(host: host, group: group);
    }
    return _ControllerList(host: host);
  }
}

/// Where a page of a [_PageStack] is: 0 when shown, 1 one page to the right,
/// -1 one page to the left.
class _PagePosition extends ParentDataWidget<_PageData> {
  const _PagePosition({
    required this.offset,
    required super.child,
    super.key,
  });

  final double offset;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _PageData;
    if (data.position == offset) return;
    data.position = offset;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _PageStack;
}

class _PageData extends ContainerBoxParentData<RenderBox> {
  double position = 0;
  final opacity = LayerHandle<OpacityLayer>();

  @override
  void detach() {
    opacity.layer = null;
    super.detach();
  }
}

/// Pages that slide horizontally. Its height blends the heights of the pages
/// on screen by how far each is shown, so a container around it resizes in
/// step with the slide.
class _PageStack extends MultiChildRenderObjectWidget {
  const _PageStack({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPageStack();
}

class _RenderPageStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PageData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PageData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PageData) child.parentData = _PageData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final pageConstraints = BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: constraints.maxHeight,
    );
    var height = 0.0;
    var weights = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as _PageData;
      child.layout(pageConstraints, parentUsesSize: true);
      final d = data.position;
      final weight = (1 - d.abs()).clamp(0.0, 1.0);
      height += weight * child.size.height;
      weights += weight;
      data.offset = Offset(width * (d < 0 ? d * 0.2 : d), 0);
    }
    size = constraints.constrain(
      Size(width, weights == 0 ? 0 : height / weights),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as _PageData;
      // Pages leaving fade out by halfway, before the container, sized for
      // the page coming in, clips much of them.
      final opacity = data.position < 0
          ? (1 + data.position * 2).clamp(0.0, 1.0)
          : 1.0;
      if (opacity <= 0 || opacity >= 1) data.opacity.layer = null;
      if (opacity <= 0) continue;
      final at = offset + data.offset;
      if (opacity >= 1) {
        context.paintChild(child, at);
      } else {
        final page = child;
        data.opacity.layer = context.pushOpacity(
          at,
          (opacity * 255).round(),
          (context, offset) => context.paintChild(page, offset),
          oldLayer: data.opacity.layer,
        );
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onMinimize,
    this.subtitle,
    this.onBack,
    this.onReset,
  });

  final String title;
  final String? subtitle;

  /// Undoes the page's changes, or null when there are none.
  final VoidCallback? onReset;

  /// Collapses the panel back into the bubble.
  final VoidCallback onMinimize;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Container(
      height: 52,
      color: palette.surface,
      padding: EdgeInsets.only(left: onBack == null ? 16 : 10, right: 10),
      child: Row(
        children: [
          if (onBack != null) ...[
            GlyphButton(
              Glyph.back,
              key: const ValueKey('motor-devtools-back'),
              onTap: onBack,
              semanticLabel: 'Back',
              size: 28,
            ),
            const SizedBox(width: 8),
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
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: palette.caption,
                  ),
                ],
              ],
            ),
          ),
          if (onReset case final onReset?) ...[
            TextAction(
              'Reset',
              key: const ValueKey('motor-devtools-reset-page'),
              onTap: onReset,
            ),
            const SizedBox(width: 10),
          ],
          GlyphButton(
            Glyph.minimize,
            key: const ValueKey('motor-devtools-minimize'),
            onTap: onMinimize,
            semanticLabel: 'Minimize Motor devtools',
            size: 28,
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
  var _mutedOpen = false;
  var _mutedIdleOpen = false;
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
          host: host,
          name: group,
          members: members,
          onTap: () => host.showGroup(group),
        ),
      for (final MapEntry(key: name, value: members) in byName.entries)
        if (members.length == 1)
          _ControllerRow(
            key: ObjectKey(members.single),
            host: host,
            controller: members.single,
            name: host.nameOf(members.single),
            onTap: () => host.showController(members.single),
          )
        else ...[
          _GroupRow(
            key: ValueKey('motor-same-$name'),
            host: host,
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
                      host: host,
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

  /// [controllers]' rows, with the ones that never played folded into an
  /// idle row.
  List<Widget> _section(
    List<TrackController> controllers, {
    required bool idleOpen,
    required ValueChanged<bool> onIdle,
    required String idleKey,
  }) {
    final host = widget.host;
    final idle = [
      for (final controller in controllers)
        if (controller.inspectionGroup == null && host.isIdle(controller))
          controller,
    ];
    return [
      ..._rows([
        for (final controller in controllers)
          if (!idle.contains(controller)) controller,
      ]),
      if (idle.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DisclosureRow(
            key: ValueKey(idleKey),
            title: '${idle.length} idle',
            trailing: 'never played',
            open: idleOpen,
            onTap: () => onIdle(!idleOpen),
          ),
        ),
        Disclosure(
          open: idleOpen,
          child: Column(children: _rows(idle)),
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
    final modified = [
      for (final controller in visible)
        if (host.changesOf(controller).isNotEmpty) controller,
    ];
    final muted = [
      for (final controller in visible)
        if (controller.isMuted && !modified.contains(controller)) controller,
    ];
    final normal = [
      for (final controller in visible)
        if (!modified.contains(controller) && !muted.contains(controller))
          controller,
    ];
    final count = visible.length;
    return ColoredBox(
      color: palette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: count == 1 ? '1 controller' : '$count controllers',
            onMinimize: host.close,
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
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      Disclosure(
                        open: modified.isNotEmpty,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionHeader(
                              key: const ValueKey(
                                'motor-devtools-modified-section',
                              ),
                              title: 'Modified',
                              count: modified.length,
                              action: TextAction(
                                'Reset all',
                                key: const ValueKey('motor-devtools-reset-all'),
                                onTap: host.resetAll,
                              ),
                            ),
                            ..._rows(modified),
                            const SizedBox(height: 4),
                            const Hairline(),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      ..._section(
                        normal,
                        idleOpen: _idleOpen,
                        onIdle: (open) => setState(() => _idleOpen = open),
                        idleKey: 'motor-devtools-idle',
                      ),
                      if (muted.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DisclosureRow(
                            key: const ValueKey('motor-devtools-muted'),
                            title: '${muted.length} muted',
                            open: _mutedOpen,
                            onTap: () =>
                                setState(() => _mutedOpen = !_mutedOpen),
                          ),
                        ),
                        Disclosure(
                          open: _mutedOpen,
                          child: Opacity(
                            opacity: 0.5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _section(
                                muted,
                                idleOpen: _mutedIdleOpen,
                                onIdle: (open) =>
                                    setState(() => _mutedIdleOpen = open),
                                idleKey: 'motor-devtools-muted-idle',
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (hidden.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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

/// A small, quiet section title with a count and an optional action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.action,
    super.key,
  });

  final String title;
  final int count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Text(title, style: palette.label),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: palette.label.copyWith(color: palette.tertiary),
            ),
            const Spacer(),
            ?action,
          ],
        ),
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
    motion: const Motion.smoothSpring(duration: Duration(milliseconds: 320)),
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
    required this.title,
    required this.subtitle,
    required this.lane,
    required this.trailing,
    this.changes = const [],
  });

  final String title;
  final String subtitle;
  final PlaybackSnapshot? lane;
  final Widget trailing;

  /// What the tools changed, shown before [subtitle] in the accent color.
  final List<String> changes;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final modified = changes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
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
                const SizedBox(height: 1),
                Text.rich(
                  TextSpan(
                    children: [
                      if (modified)
                        TextSpan(
                          text: changes.join('  ·  '),
                          style: TextStyle(color: palette.accent),
                        ),
                      if (modified && subtitle.isNotEmpty)
                        const TextSpan(text: '  ·  '),
                      TextSpan(text: subtitle),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (modified) ...[
            Container(
              key: const ValueKey('motor-devtools-modified'),
              width: 6,
              height: 6,
              decoration: ShapeDecoration(
                color: palette.accent,
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (lane case final lane?)
            SizedBox(
              width: 56,
              height: 6,
              child: SummaryLane(snapshot: lane),
            ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _ControllerRow extends StatelessWidget {
  const _ControllerRow({
    required this.host,
    required this.controller,
    required this.name,
    required this.onTap,
    super.key,
  });

  final PanelHost host;
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
            final changes = host.changesOf(controller);
            final muted = controller.isMuted;
            return _RowLayout(
              title: name,
              changes: changes,
              subtitle: [
                if (muted)
                  'Muted'
                else if (changes.isEmpty)
                  PlaybackState.of(controller).label,
                if (changes.isEmpty) _trackSummary(controller),
              ].join('  ·  '),
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
    required this.host,
    required this.name,
    required this.members,
    required this.onTap,
    this.open,
    super.key,
  });

  final PanelHost host;
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
            final muted = members.every((c) => c.isMuted);
            final modified = members
                .where((c) => host.changesOf(c).isNotEmpty)
                .length;
            return _RowLayout(
              title: title,
              changes: [if (modified > 0) '$modified modified'],
              subtitle: [
                if (muted)
                  'Muted'
                else if (playing > 0)
                  '$playing playing'
                else
                  state.label,
                _trackSummary(members.first),
              ].join('  ·  '),
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

/// The state shown in a page header. Pausing lasts only while the page is
/// open, so it says so.
String _stateLabel(PlaybackState state, {required bool muted}) {
  if (muted) return 'Muted';
  if (state == PlaybackState.paused) return 'Paused, resumes when you leave';
  return state.label;
}

/// Says a controller is muted, unfolding while [muted].
class _MutedNote extends StatelessWidget {
  const _MutedNote({required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) => Disclosure(
    open: muted,
    child: const Padding(
      padding: EdgeInsets.only(top: 12),
      child: Note(
        key: ValueKey('motor-devtools-muted-note'),
        'Muted: its ticker is muted, so it does not move until it is '
        'unmuted.',
      ),
    ),
  );
}

const _speeds = [0.1, 0.25, 0.5, 1.0];

/// A playback speed, such as `0.25×`.
String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.round() : speed}×';

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
        ),
        const SizedBox(width: 8),
        GlyphButton(
          Glyph.replay,
          key: const ValueKey('motor-devtools-replay'),
          onTap: onReplay,
          semanticLabel: 'Replay',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Segmented<double>(
            options: _speeds,
            selected: _speeds.contains(speed) ? speed : null,
            labelOf: speedLabel,
            keyOf: (speed) => ValueKey('motor-devtools-speed-$speed'),
            onSelected: onSpeed,
          ),
        ),
      ],
    );
  }
}

class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.host, required this.group});

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
          final muted = members.isNotEmpty && members.every((c) => c.isMuted);
          final changed =
              settings.speed != null ||
              settings.overrides.isNotEmpty ||
              members.any((c) => host.changesOf(c).isNotEmpty);
          final labels = {
            for (final member in members)
              for (final playback in member.inspectPlayback().tracks)
                if (playback.track.debugLabel case final label?) label,
          };
          final tracks = <(String?, String)>[
            (null, 'All tracks'),
            for (final label in labels) (label, label),
          ];
          return _GroupEditor(
            host: host,
            group: group,
            header: _Header(
              title: '$group ×${members.length}',
              subtitle: '${_stateLabel(state, muted: muted)}  ·  group',
              onBack: host.back,
              onMinimize: host.close,
              onReset: changed ? () => host.resetGroup(group) : null,
            ),
            muted: muted,
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
            settings: settings,
            members: [
              for (final member in members)
                _ControllerRow(
                  key: ObjectKey(member),
                  host: host,
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
    required this.settings,
    required this.members,
    required this.muted,
  });

  final PanelHost host;
  final String group;
  final Widget header;
  final Widget transport;
  final List<(String?, String)> tracks;
  final GroupSettings settings;
  final List<Widget> members;
  final bool muted;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  String? _open;
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final palette = DevToolsTheme.of(context);
    final overrides = widget.settings.overrides;
    final appMotions = widget.host.appMotions;
    void apply(String? key, Motion? motion, {bool replay = true}) {
      widget.host.setGroupOverride(widget.group, key, motion, replay: replay);
      setState(() {});
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header,
        const Hairline(),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.transport,
                    _MutedNote(muted: widget.muted),
                    const SizedBox(height: 12),
                    Text('Motion', style: palette.label),
                    const SizedBox(height: 4),
                    for (final (key, name) in widget.tracks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: EditableTrack(
                          name: name,
                          tuned: overrides.containsKey(key)
                              ? describeMotion(overrides[key], appMotions)
                              : null,
                          editing: _editing && _open == key,
                          dimmed: _editing && _open != key,
                          onEdit: () => setState(() {
                            _editing = true;
                            _open = key;
                          }),
                          onDone: () => setState(() => _editing = false),
                          onReset: () => apply(key, null),
                          editor: MotionEditor(
                            current: overrides[key],
                            appMotions: appMotions,
                            onChanged: (motion) => apply(key, motion),
                            onTuned: (motion) =>
                                apply(key, motion, replay: false),
                          ),
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
  const _ControllerDetail({required this.host, required this.controller});

  final PanelHost host;
  final TrackController controller;

  @override
  State<_ControllerDetail> createState() => _ControllerDetailState();
}

class _ControllerDetailState extends State<_ControllerDetail> {
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
          final overrides = controller.motionOverrides;
          final speed = controller.playbackSpeed;
          final group = controller.inspectionGroup;
          final muted = controller.isMuted;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: host.nameOf(controller),
                subtitle: [
                  _stateLabel(state, muted: muted),
                  if (speed != 1) speedLabel(speed),
                  if (group != null) 'in $group',
                ].join('  ·  '),
                onBack: host.back,
                onMinimize: host.close,
                onReset: host.changesOf(controller).isEmpty
                    ? null
                    : () => host.reset(controller),
              ),
              const Hairline(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    _MutedNote(muted: muted),
                    const SizedBox(height: 14),
                    Timeline(
                      key: const ValueKey('motor-devtools-full-timeline'),
                      controller: controller,
                      trackMotion: (track) => overrides.containsKey(track)
                          ? describeMotion(overrides[track], host.appMotions)
                          : null,
                      onResetTrack: (track) =>
                          host.setOverride(controller, track, null),
                      trackEditor: (track) => MotionEditor(
                        current: overrides[track],
                        appMotions: host.appMotions,
                        onChanged: (motion) =>
                            host.setOverride(controller, track, motion),
                        onTuned: (motion) => host.setOverride(
                          controller,
                          track,
                          motion,
                          replay: false,
                        ),
                      ),
                    ),
                    if (controller.debugLabel == null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: ShapeDecoration(
                          color: palette.fill,
                          shape: rounded(10),
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
