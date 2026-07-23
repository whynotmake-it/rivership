import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/motor_timeline.dart';

const _surface = Color(0xFF090909);
const _raised = Color(0xFF111111);
const _stroke = Color(0xFF292929);
const _accent = Color(0xFFF4F4F4);
const _muted = Color(0xFF9B9B9B);

/// Imperatively opens and closes a [MotorDevTools] overlay.
class MotorDevToolsController extends ChangeNotifier {
  bool _isOpen = false;
  TrackController? _selectedController;

  /// Whether the full inspector is visible.
  bool get isOpen => _isOpen;

  /// The controller currently shown in detail, if any.
  TrackController? get selectedController => _selectedController;

  /// Opens the inspector, optionally on [controller].
  void open([TrackController? controller]) {
    _isOpen = true;
    _selectedController = controller;
    notifyListeners();
  }

  /// Returns to the controller list.
  void showControllerList() {
    _selectedController = null;
    notifyListeners();
  }

  /// Opens the detail view for [controller].
  void showController(TrackController controller) {
    _isOpen = true;
    _selectedController = controller;
    notifyListeners();
  }

  /// Closes the inspector.
  void close() {
    _isOpen = false;
    notifyListeners();
  }

  /// Toggles the inspector.
  void toggle() => _isOpen ? close() : open();
}

/// An optional, in-app inspector and motion studio for Motor.
///
/// Place this above the controllers it should discover. The recommended
/// location is an app's `builder`, which keeps navigation and inherited app
/// configuration available to [child]:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => MotorDevTools(
///     enabled: kDebugMode,
///     child: child!,
///   ),
/// )
/// ```
///
/// [enabled] can deliberately be true in a production build. When false, the
/// child is returned directly and Motor's inspection registry is not attached.
/// Apps that never import `motor_devtools` can tree-shake the entire package.
class MotorDevTools extends StatefulWidget {
  /// Creates an optional Motor developer overlay.
  const MotorDevTools({
    required this.child,
    this.enabled = true,
    this.controller,
    this.alignment = Alignment.bottomRight,
    super.key,
  });

  /// The application subtree to inspect.
  final Widget child;

  /// Whether controller discovery and overlay UI are enabled.
  final bool enabled;

  /// An optional imperative overlay controller.
  final MotorDevToolsController? controller;

  /// The launcher and panel alignment.
  final Alignment alignment;

  @override
  State<MotorDevTools> createState() => _MotorDevToolsState();
}

class _MotorDevToolsState extends State<MotorDevTools>
    implements MotorInspectionObserver {
  final _controllers = <TrackController>[];
  final _controllerNumbers = <TrackController, int>{};
  final _originalSpeeds = <TrackController, double>{};
  final _originalOverrides = <TrackController, Map<Track<Object>, Motion>>{};
  MotorInspectionSubscription? _subscription;
  MotorDevToolsController? _ownedController;
  var _nextControllerNumber = 1;
  var _refreshScheduled = false;

  MotorDevToolsController get _overlayController =>
      widget.controller ?? (_ownedController ??= MotorDevToolsController());

  @override
  void initState() {
    super.initState();
    _overlayController.addListener(_overlayChanged);
    if (widget.enabled) _attach();
  }

  @override
  void didUpdateWidget(MotorDevTools oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      final oldController = oldWidget.controller ?? _ownedController;
      oldController?.removeListener(_overlayChanged);
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _overlayController.addListener(_overlayChanged);
    }
    if (oldWidget.enabled != widget.enabled) {
      widget.enabled ? _attach() : _detach();
    }
  }

  void _attach() {
    _subscription ??= MotorInspectionRegistry.attach(this);
  }

  void _detach() {
    _restoreSessionChanges();
    _subscription?.dispose();
    _subscription = null;
    _controllers.clear();
    _overlayController.close();
  }

  void _overlayChanged() {
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (!mounted || _refreshScheduled) return;
    _refreshScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void didRegisterController(TrackController controller) {
    if (_controllers.contains(controller)) return;
    _controllerNumbers[controller] = _nextControllerNumber++;
    _controllers.add(controller);
    _scheduleRefresh();
  }

  @override
  void didUnregisterController(TrackController controller) {
    if (!_controllers.contains(controller)) return;
    if (identical(_overlayController.selectedController, controller)) {
      _overlayController.showControllerList();
    }
    _controllers.remove(controller);
    _originalSpeeds.remove(controller);
    _originalOverrides.remove(controller);
    _scheduleRefresh();
  }

  String _nameFor(TrackController controller) {
    final number = (_controllerNumbers[controller] ?? 0).toString().padLeft(
      2,
      '0',
    );
    return controller.debugLabel ?? 'Controller $number';
  }

  void _setSpeed(TrackController controller, double speed) {
    _originalSpeeds.putIfAbsent(controller, () => controller.playbackSpeed);
    controller.playbackSpeed = speed;
    setState(() {});
  }

  void _setOverride(
    TrackController controller,
    Track<Object> track,
    Motion? motion,
  ) {
    _originalOverrides.putIfAbsent(
      controller,
      () => Map.of(controller.motionOverrides),
    );
    controller
      ..setMotionOverride(track, motion)
      ..replay();
    setState(() {});
  }

  void _restoreSessionChanges() {
    for (final entry in _originalSpeeds.entries) {
      if (_controllers.contains(entry.key)) {
        entry.key.playbackSpeed = entry.value;
      }
    }
    for (final entry in _originalOverrides.entries) {
      if (!_controllers.contains(entry.key)) continue;
      final controller = entry.key;
      final currentTracks = controller.motionOverrides.keys.toSet();
      for (final track in currentTracks) {
        controller.setMotionOverride(track, null);
      }
      for (final override in entry.value.entries) {
        controller.setMotionOverride(override.key, override.value);
      }
    }
    _originalSpeeds.clear();
    _originalOverrides.clear();
  }

  @override
  void dispose() {
    _restoreSessionChanges();
    _subscription?.dispose();
    final controller = widget.controller ?? _ownedController;
    controller?.removeListener(_overlayChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        Positioned.fill(
          child: _FloatingChrome(
            isOpen: _overlayController.isOpen,
            controllerCount: _controllers.length,
            trackCount: _controllers.fold(
              0,
              (count, controller) =>
                  count + controller.inspectPlayback().tracks.length,
            ),
            initialAlignment: widget.alignment,
            onExpand: _overlayController.open,
            peekController: _peekController,
            peekName: _peekController == null
                ? null
                : _nameFor(_peekController!),
            panel: _buildPanel(),
          ),
        ),
      ],
    );
  }

  TrackController? get _peekController {
    final selected = _overlayController.selectedController;
    if (selected != null && _controllers.contains(selected)) return selected;
    for (final controller in _controllers.reversed) {
      if (controller.inspectPlayback().tracks.isNotEmpty) return controller;
    }
    return _controllers.lastOrNull;
  }

  Widget _buildPanel() {
    final selected = _overlayController.selectedController;
    return selected != null && _controllers.contains(selected)
        ? _ControllerDetail(
            key: ValueKey(selected),
            controller: selected,
            name: _nameFor(selected),
            onBack: _overlayController.showControllerList,
            onClose: _overlayController.close,
            onSpeedChanged: (speed) => _setSpeed(selected, speed),
            onOverrideChanged: (track, motion) =>
                _setOverride(selected, track, motion),
          )
        : _ControllerList(
            controllers: _controllers,
            nameFor: _nameFor,
            onSelected: _overlayController.showController,
            onClose: _overlayController.close,
          );
  }
}

class _FloatingChrome extends StatefulWidget {
  const _FloatingChrome({
    required this.isOpen,
    required this.controllerCount,
    required this.trackCount,
    required this.initialAlignment,
    required this.onExpand,
    required this.peekController,
    required this.peekName,
    required this.panel,
  });

  final bool isOpen;
  final int controllerCount;
  final int trackCount;
  final Alignment initialAlignment;
  final VoidCallback onExpand;
  final TrackController? peekController;
  final String? peekName;
  final Widget panel;

  @override
  State<_FloatingChrome> createState() => _FloatingChromeState();
}

class _FloatingChromeState extends State<_FloatingChrome> {
  static const _collapsedSize = Size(204, 72);
  static const _peekSize = Size(318, 166);
  static const _inset = 12.0;

  late Alignment _anchor = widget.initialAlignment;
  Offset? _dragPosition;
  var _dragging = false;
  var _isPeek = false;
  var _locallyExpanded = false;

  bool get _isFull => widget.isOpen || _locallyExpanded;

  @override
  void didUpdateWidget(_FloatingChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen && !widget.isOpen) _locallyExpanded = false;
  }

  void _expand() {
    setState(() => _locallyExpanded = true);
    widget.onExpand();
  }

  Offset _anchoredPosition(Size stage, Size object) => Offset(
    _anchor.x < 0 ? _inset : stage.width - object.width - _inset,
    _anchor.y < 0 ? _inset : stage.height - object.height - _inset,
  );

  Offset _clamp(Offset position, Size stage, Size object) => Offset(
    position.dx.clamp(_inset, stage.width - object.width - _inset),
    position.dy.clamp(_inset, stage.height - object.height - _inset),
  );

  void _updateDrag(DragUpdateDetails details, Size stage, Size object) {
    final current = _dragPosition ?? _anchoredPosition(stage, object);
    setState(() {
      _dragging = true;
      _dragPosition = _clamp(current + details.delta, stage, object);
    });
  }

  void _finishDrag(DragEndDetails details, Size stage, Size object) {
    final current = _dragPosition ?? _anchoredPosition(stage, object);
    final projected = current + details.velocity.pixelsPerSecond * 0.12;
    final center =
        projected +
        Offset(
          object.width / 2,
          object.height / 2,
        );
    setState(() {
      _anchor = Alignment(
        center.dx < stage.width / 2 ? -1 : 1,
        center.dy < stage.height / 2 ? -1 : 1,
      );
      _dragPosition = null;
      _dragging = false;
    });
    if (details.velocity.pixelsPerSecond.dy < -800) {
      if (_isPeek) {
        _expand();
      } else {
        setState(() => _isPeek = true);
      }
    } else if (details.velocity.pixelsPerSecond.dy > 800 && _isPeek) {
      setState(() => _isPeek = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery =
        MediaQuery.maybeOf(context)?.copyWith(
          textScaler: TextScaler.noScaling,
        ) ??
        MediaQueryData.fromView(ui.PlatformDispatcher.instance.views.first);
    return MediaQuery(
      data: mediaQuery,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data:
              ThemeData(
                brightness: Brightness.dark,
                useMaterial3: true,
                fontFamily: 'Roboto',
                fontFamilyFallback: const ['Roboto'],
              ).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: _accent,
                  secondary: _muted,
                  surface: _surface,
                ),
              ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stage = constraints.biggest;
                final expandedSize = Size(
                  (stage.width - _inset * 2).clamp(0, 430),
                  (stage.height - _inset * 2).clamp(0, 720),
                );
                final objectSize = _isFull
                    ? expandedSize
                    : _isPeek
                    ? _peekSize
                    : _collapsedSize;
                final position = _dragPosition == null
                    ? _anchoredPosition(stage, objectSize)
                    : _clamp(_dragPosition!, stage, objectSize);
                return Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    AnimatedPositioned(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      left: position.dx,
                      top: position.dy,
                      child: AnimatedContainer(
                        key: _isFull
                            ? const ValueKey('motor-devtools-panel')
                            : _isPeek
                            ? const ValueKey('motor-devtools-peek')
                            : const ValueKey('motor-devtools-launcher'),
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        width: objectSize.width,
                        height: objectSize.height,
                        decoration: BoxDecoration(
                          color: _surface,
                          border: Border.all(color: _stroke),
                          borderRadius: BorderRadius.circular(
                            _isFull ? 18 : 16,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              ignoring: _isFull || _isPeek,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                opacity: _isFull || _isPeek ? 0 : 1,
                                child: _CollapsedLauncher(
                                  count: widget.controllerCount,
                                  trackCount: widget.trackCount,
                                  dragging: _dragging,
                                  onTap: () => setState(() => _isPeek = true),
                                  onPanUpdate: (details) => _updateDrag(
                                    details,
                                    stage,
                                    _collapsedSize,
                                  ),
                                  onPanEnd: (details) => _finishDrag(
                                    details,
                                    stage,
                                    _collapsedSize,
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: _isFull || !_isPeek,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: !_isFull && _isPeek ? 1 : 0,
                                child: _PeekLauncher(
                                  controller: widget.peekController,
                                  name: widget.peekName,
                                  count: widget.controllerCount,
                                  onExpand: _expand,
                                  onCollapse: () =>
                                      setState(() => _isPeek = false),
                                  onPanUpdate: (details) =>
                                      _updateDrag(details, stage, _peekSize),
                                  onPanEnd: (details) =>
                                      _finishDrag(details, stage, _peekSize),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !_isFull,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 220),
                                opacity: _isFull ? 1 : 0,
                                child: Material(
                                  color: Colors.transparent,
                                  child: widget.panel,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedLauncher extends StatelessWidget {
  const _CollapsedLauncher({
    required this.count,
    required this.trackCount,
    required this.dragging,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final int count;
  final int trackCount;
  final bool dragging;
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final ValueChanged<DragEndDetails> onPanEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open Motor devtools, $count controllers',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const _MotorMark(size: 34),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOTOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count controllers  ·  $trackCount tracks',
                      maxLines: 1,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 180),
                turns: dragging ? 0.125 : 0,
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  color: _muted,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeekLauncher extends StatelessWidget {
  const _PeekLauncher({
    required this.controller,
    required this.name,
    required this.count,
    required this.onExpand,
    required this.onCollapse,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final TrackController? controller;
  final String? name;
  final int count;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final ValueChanged<DragEndDetails> onPanEnd;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller?.inspectPlayback();
    final track = snapshot?.tracks.firstOrNull?.track;
    final isPlaying =
        snapshot?.status == AnimationStatus.forward ||
        snapshot?.status == AnimationStatus.reverse;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          onDoubleTap: onExpand,
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const _MotorMark(size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? '$count controllers',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track?.debugLabel ??
                              (isPlaying ? 'PLAYING' : 'NO ACTIVE TRACK'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Collapse Motor devtools',
                    child: IconButton(
                      key: const ValueKey('motor-devtools-peek-collapse'),
                      onPressed: onCollapse,
                      icon: const Icon(Icons.remove_rounded, size: 18),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Expand Motor devtools',
                    child: IconButton(
                      key: const ValueKey('motor-devtools-peek-expand'),
                      onPressed: onExpand,
                      icon: const Icon(Icons.open_in_full_rounded, size: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: _stroke),
        Expanded(
          child: controller == null || track == null
              ? const Center(
                  child: Text(
                    'Motion will appear here',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: MotorTimeline(
                    key: const ValueKey('motor-devtools-peek-timeline'),
                    controller: controller!,
                    track: track,
                  ),
                ),
        ),
      ],
    );
  }
}

class _MotorMark extends StatelessWidget {
  const _MotorMark({this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Text(
      'M',
      style: TextStyle(
        color: const Color(0xFF111318),
        fontSize: size * 0.52,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _ControllerList extends StatelessWidget {
  const _ControllerList({
    required this.controllers,
    required this.nameFor,
    required this.onSelected,
    required this.onClose,
  });

  final List<TrackController> controllers;
  final String Function(TrackController) nameFor;
  final ValueChanged<TrackController> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(title: 'LIVE CONTROLLERS', onClose: onClose),
        Flexible(
          child: controllers.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  shrinkWrap: true,
                  itemCount: controllers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final controller = controllers[index];
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => _ControllerCard(
                        controller: controller,
                        name: nameFor(controller),
                        onTap: () => onSelected(controller),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onClose,
    this.onBack,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
      child: Row(
        children: [
          if (onBack != null) ...[
            Semantics(
              button: true,
              label: 'All controllers',
              child: ExcludeSemantics(
                child: IconButton(
                  key: const ValueKey('motor-devtools-back'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 19),
                ),
              ),
            ),
            const SizedBox(width: 2),
          ] else ...[
            const _MotorMark(),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MOTOR / DEVTOOLS',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Close devtools',
            child: ExcludeSemantics(
              child: IconButton(
                key: const ValueKey('motor-devtools-close'),
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(30, 42, 30, 52),
      child: Column(
        children: [
          Icon(Icons.radar_rounded, color: _accent, size: 34),
          SizedBox(height: 14),
          Text(
            'Waiting for motion',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 7),
          Text(
            'Controllers created below this widget will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA7AAB3), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ControllerCard extends StatelessWidget {
  const _ControllerCard({
    required this.controller,
    required this.name,
    required this.onTap,
  });

  final TrackController controller;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.inspectPlayback();
    final isActive =
        snapshot.status == AnimationStatus.forward ||
        snapshot.status == AnimationStatus.reverse;
    return Material(
      color: _raised,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('motor-controller-$name'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _stroke),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : _stroke,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? const [
                          BoxShadow(color: Color(0x44FFFFFF), blurRadius: 8),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.tracks.length} tracks  ·  '
                      '${controller.playbackSpeed}x  ·  '
                      '${isActive ? 'PLAYING' : 'IDLE'}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
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
  final void Function(Track<Object>, Motion?) onOverrideChanged;

  @override
  State<_ControllerDetail> createState() => _ControllerDetailState();
}

class _ControllerDetailState extends State<_ControllerDetail> {
  Track<Object>? _selectedTrack;
  var _duration = 500.0;
  var _bounce = 0.15;
  var _editorMode = _MotionEditorMode.spring;
  var _curve = _CurveChoice.easeInOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snapshot = widget.controller.inspectPlayback();
        final tracks = snapshot.tracks
            .map((playback) => playback.track)
            .toList();
        if (_selectedTrack == null || !tracks.contains(_selectedTrack)) {
          _selectedTrack = tracks.firstOrNull;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: widget.name,
              onBack: widget.onBack,
              onClose: widget.onClose,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PlaybackControls(
                      controller: widget.controller,
                      onSpeedChanged: widget.onSpeedChanged,
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('TIMELINE / DRAG TO SCRUB'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      decoration: BoxDecoration(
                        color: _raised,
                        border: Border.all(color: _stroke),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: MotorTimeline(
                        key: const ValueKey('motor-devtools-full-timeline'),
                        controller: widget.controller,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStudio(tracks),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudio(List<Track<Object>> tracks) {
    final track = _selectedTrack;
    if (track == null) {
      return const _StudioEmpty();
    }
    final overridden = widget.controller.motionOverrides.containsKey(track);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _raised,
        border: Border.all(color: _stroke),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('MOTION STUDIO')),
              if (overridden)
                const Text(
                  'SESSION OVERRIDE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Tune a track and replay the latest clip instantly.',
            style: TextStyle(color: Color(0xFF999DA8), fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            key: const ValueKey('motor-devtools-track-picker'),
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _TrackCard(
                label: tracks[index].debugLabel ?? 'Track ${index + 1}',
                index: index,
                selected: identical(track, tracks[index]),
                overridden: widget.controller.motionOverrides.containsKey(
                  tracks[index],
                ),
                onTap: () => setState(() => _selectedTrack = tracks[index]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EditorModeCard(
                  key: const ValueKey('motor-devtools-mode-spring'),
                  title: 'Spring field',
                  subtitle: 'duration × bounce',
                  selected: _editorMode == _MotionEditorMode.spring,
                  onTap: () => setState(
                    () => _editorMode = _MotionEditorMode.spring,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditorModeCard(
                  key: const ValueKey('motor-devtools-mode-curve'),
                  title: 'Curve lab',
                  subtitle: 'duration + easing',
                  selected: _editorMode == _MotionEditorMode.curve,
                  onTap: () => setState(
                    () => _editorMode = _MotionEditorMode.curve,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_editorMode == _MotionEditorMode.spring)
            _SpringField(
              key: const ValueKey('motor-devtools-spring-field'),
              duration: _duration,
              bounce: _bounce,
              onChanged: (value) => setState(() {
                _duration = value.$1;
                _bounce = value.$2;
              }),
              onChangeEnd: _apply,
            )
          else ...[
            _LabeledSlider(
              label: 'DURATION',
              valueLabel: '${_duration.round()} ms',
              value: _duration,
              min: 120,
              max: 1200,
              divisions: 36,
              onChanged: (value) => setState(() => _duration = value),
              onChangeEnd: (_) => _apply(),
            ),
            const SizedBox(height: 12),
            const _SectionLabel('EASING CURVE'),
            const SizedBox(height: 8),
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.35,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final choice in _CurveChoice.values)
                  _CurveCard(
                    choice: choice,
                    selected: _curve == choice,
                    onTap: () {
                      setState(() => _curve = choice);
                      _apply();
                    },
                  ),
              ],
            ),
          ],
          if (overridden) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('motor-devtools-reset-motion'),
              onPressed: () => widget.onOverrideChanged(track, null),
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('Restore authored motion'),
            ),
          ],
        ],
      ),
    );
  }

  void _apply() {
    final track = _selectedTrack;
    if (track == null) return;
    final duration = Duration(milliseconds: _duration.round());
    final motion = switch (_editorMode) {
      _MotionEditorMode.spring => Motion.cupertino(
        duration: duration,
        bounce: _bounce,
      ),
      _MotionEditorMode.curve => Motion.curved(duration, _curve.curve),
    };
    widget.onOverrideChanged(track, motion);
  }
}

enum _MotionEditorMode { spring, curve }

enum _CurveChoice {
  easeOut('Ease out', Curves.easeOutCubic),
  easeInOut('Ease in/out', Curves.easeInOutCubic),
  emphasized('Emphasized', Curves.fastEaseInToSlowEaseOut),
  linear('Linear', Curves.linear);

  const _CurveChoice(this.label, this.curve);

  final String label;
  final Curve curve;
}

class _PlaybackControls extends StatefulWidget {
  const _PlaybackControls({
    required this.controller,
    required this.onSpeedChanged,
  });

  final TrackController controller;
  final ValueChanged<double> onSpeedChanged;

  @override
  State<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<_PlaybackControls> {
  var _paused = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: _paused ? 'Resume' : 'Pause',
          child: ExcludeSemantics(
            child: IconButton.filled(
              key: const ValueKey('motor-devtools-play-pause'),
              onPressed: () {
                setState(() => _paused = !_paused);
                _paused
                    ? widget.controller.pause()
                    : widget.controller.resume();
              },
              icon: Icon(
                _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 19,
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Replay',
          child: ExcludeSemantics(
            child: IconButton(
              key: const ValueKey('motor-devtools-replay'),
              onPressed: widget.controller.replay,
              icon: const Icon(Icons.replay_rounded, size: 19),
            ),
          ),
        ),
        const Spacer(),
        for (final speed in const [0.25, 0.5, 1.0]) ...[
          if (speed != 0.25) const SizedBox(width: 5),
          _SpeedChip(
            speed: speed,
            selected: widget.controller.playbackSpeed == speed,
            onTap: () => widget.onSpeedChanged(speed),
          ),
        ],
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final double speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${speed.toString().replaceAll('.0', '')}×';
    return InkWell(
      key: ValueKey('motor-devtools-speed-$speed'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _accent : _raised,
          border: Border.all(color: selected ? _accent : _stroke),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF111318) : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _SectionLabel(label),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            void update(double x, {required bool ended}) {
              final fraction = (x / constraints.maxWidth).clamp(0.0, 1.0);
              final raw = min + (max - min) * fraction;
              final step = (max - min) / divisions;
              final snapped = min + ((raw - min) / step).round() * step;
              onChanged(snapped.clamp(min, max));
              if (ended) onChangeEnd(snapped.clamp(min, max));
            }

            final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
            return Semantics(
              slider: true,
              value: valueLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => update(
                  details.localPosition.dx,
                  ended: true,
                ),
                onHorizontalDragUpdate: (details) => update(
                  details.localPosition.dx,
                  ended: false,
                ),
                onHorizontalDragEnd: (_) => onChangeEnd(value),
                child: SizedBox(
                  height: 22,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: _stroke,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(fraction * 2 - 1, 0),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.label,
    required this.index,
    required this.selected,
    required this.overridden,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool selected;
  final bool overridden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 146,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF202020) : _surface,
          border: Border.all(color: selected ? _accent : _stroke),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : _stroke,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? Colors.black : _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overridden ? 'TUNED' : 'AUTHORED',
                    style: TextStyle(
                      color: overridden
                          ? Colors.white
                          : const Color(0xFF666666),
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorModeCard extends StatelessWidget {
  const _EditorModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: selected ? Colors.white : _surface,
        border: Border.all(color: selected ? Colors.white : _stroke),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: selected ? const Color(0xFF555555) : _muted,
              fontSize: 8,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpringField extends StatelessWidget {
  const _SpringField({
    required this.duration,
    required this.bounce,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  final double duration;
  final double bounce;
  final ValueChanged<(double, double)> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SectionLabel('SPRING FIELD'),
            const Spacer(),
            Text(
              '${duration.round()} ms  ·  ${bounce.toStringAsFixed(2)} bounce',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.75,
          child: LayoutBuilder(
            builder: (context, constraints) {
              void update(Offset point) {
                final x = (point.dx / constraints.maxWidth).clamp(0.0, 1.0);
                final y = (point.dy / constraints.maxHeight).clamp(0.0, 1.0);
                final nextDuration = 120 + x * 1080;
                final nextBounce = 0.8 - y;
                onChanged((nextDuration, nextBounce));
              }

              return Semantics(
                label: 'Spring duration and bounce field',
                value:
                    '${duration.round()} milliseconds, '
                    '${bounce.toStringAsFixed(2)} bounce',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    update(details.localPosition);
                    onChangeEnd();
                  },
                  onPanUpdate: (details) => update(details.localPosition),
                  onPanEnd: (_) => onChangeEnd(),
                  child: CustomPaint(
                    painter: _SpringFieldPainter(
                      duration: duration,
                      bounce: bounce,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Text('120 MS', style: TextStyle(color: _muted, fontSize: 7)),
            Spacer(),
            Text('DURATION', style: TextStyle(color: _muted, fontSize: 7)),
            Spacer(),
            Text('1200 MS', style: TextStyle(color: _muted, fontSize: 7)),
          ],
        ),
      ],
    );
  }
}

class _SpringFieldPainter extends CustomPainter {
  const _SpringFieldPainter({required this.duration, required this.bounce});

  final double duration;
  final double bounce;

  @override
  void paint(Canvas canvas, Size size) {
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(background, Paint()..color = _surface);
    final gridPaint = Paint()
      ..color = const Color(0xFF242424)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), gridPaint)
        ..drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final response = Path()..moveTo(0, size.height * 0.78);
    for (var pixel = 1.0; pixel <= size.width; pixel += 2) {
      final t = pixel / size.width;
      final decay = math.exp(-t * (4.5 - bounce.clamp(-0.2, 0.8)));
      final wave = math.cos(t * math.pi * (3.2 + bounce * 3));
      final value = 1 - decay * wave;
      response.lineTo(pixel, size.height * (0.78 - value * 0.52));
    }
    canvas.drawPath(
      response,
      Paint()
        ..color = const Color(0xFF777777)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final x = size.width * ((duration - 120) / 1080).clamp(0.0, 1.0);
    final y = size.height * (0.8 - bounce).clamp(0.0, 1.0);
    final crosshair = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset(x, 0), Offset(x, size.height), crosshair)
      ..drawLine(Offset(0, y), Offset(size.width, y), crosshair)
      ..drawCircle(Offset(x, y), 8, Paint()..color = Colors.white)
      ..drawCircle(Offset(x, y), 3, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_SpringFieldPainter oldDelegate) =>
      oldDelegate.duration != duration || oldDelegate.bounce != bounce;
}

class _CurveCard extends StatelessWidget {
  const _CurveCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _CurveChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF242424) : _surface,
        border: Border.all(color: selected ? Colors.white : _stroke),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 26,
            child: CustomPaint(
              painter: _CurvePreviewPainter(choice.curve),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              choice.label,
              style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CurvePreviewPainter extends CustomPainter {
  const _CurvePreviewPainter(this.curve);

  final Curve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    for (var i = 1; i <= 24; i++) {
      final t = i / 24;
      path.lineTo(size.width * t, size.height * (1 - curve.transform(t)));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CurvePreviewPainter oldDelegate) =>
      oldDelegate.curve != curve;
}

class _StudioEmpty extends StatelessWidget {
  const _StudioEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _raised,
        border: Border.all(color: _stroke),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          _SectionLabel('MOTION STUDIO'),
          SizedBox(height: 9),
          Text(
            'Play a track clip to make its motions available for tuning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF999DA8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
