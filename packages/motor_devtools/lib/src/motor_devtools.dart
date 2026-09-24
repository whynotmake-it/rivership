import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/flag.dart';
import 'package:motor_devtools/src/naming.dart';
import 'package:motor_devtools/src/overlay.dart';
import 'package:motor_devtools/src/panel.dart';
import 'package:motor_devtools/src/session.dart';
import 'package:motor_devtools/src/style.dart';

/// Imperatively opens and closes a [MotorDevTools] overlay.
class MotorDevToolsController extends ChangeNotifier {
  bool _isOpen = false;
  TrackController? _selectedController;

  /// Whether the panel is expanded.
  bool get isOpen => _isOpen;

  /// The controller currently shown in detail, if any.
  TrackController? get selectedController => _selectedController;

  /// Opens the panel, optionally on [controller].
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

  /// Collapses the panel back into the bubble.
  void close() {
    _isOpen = false;
    notifyListeners();
  }

  /// Toggles the panel.
  void toggle() => _isOpen ? close() : open(_selectedController);
}

/// An optional, in-app inspector for Motor.
///
/// Shows a small floating bubble above [child]. Drag it anywhere; it settles
/// on the nearest side. Tap it to see every live Motor controller, and tap a
/// controller to pause, scrub, slow down, replay, or retune its motion.
///
/// Place it in an app's `builder` or around the app:
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
/// Controllers are listed by their `debugLabel`, which `TrackController`,
/// `MotionController`, and motor's builder widgets accept.
///
/// Three switches, from coarsest to finest:
///
/// - [kMotorDevTools] compiles the tools in or out of a build.
/// - [enabled] turns tracking on or off at runtime, also in production
///   builds. When false, the child is returned directly, Motor's inspection
///   registry is not attached, and the session's changes are undone.
/// - [visible] shows or hides the overlay while tracking goes on, keeping
///   the controllers found so far and every change, such as for a debug
///   menu that opens the tools when needed.
class MotorDevTools extends StatefulWidget {
  /// Creates an optional Motor developer overlay.
  const MotorDevTools({
    required this.child,
    this.enabled = true,
    this.visible = true,
    this.controller,
    this.alignment = Alignment.bottomRight,
    this.motions = const {},
    super.key,
  });

  /// The app's own motions, by name, offered for every track next to the
  /// built-in spring and curve.
  ///
  /// ```dart
  /// MotorDevTools(
  ///   motions: {'Sheet': AppMotion.sheet, 'Button': AppMotion.button},
  ///   child: app,
  /// )
  /// ```
  final Map<String, Motion> motions;

  /// The application subtree to inspect.
  final Widget child;

  /// Whether the tools track controllers. See [MotorDevTools] for how this
  /// differs from [visible].
  final bool enabled;

  /// Whether the overlay is shown while [enabled]. Hiding it keeps tracking
  /// and all changes; pausing and scrubbing resume, as when the panel is
  /// minimized.
  final bool visible;

  /// An optional imperative overlay controller.
  final MotorDevToolsController? controller;

  /// Where the bubble starts out.
  final Alignment alignment;

  @override
  State<MotorDevTools> createState() => _MotorDevToolsState();
}

class _MotorDevToolsState extends State<MotorDevTools> implements PanelHost {
  final _controllers = <TrackController>[];
  final _numbers = <TrackController, int>{};
  final _creations = <TrackController, StackTrace>{};
  final _guessedNames = <TrackController, String?>{};
  final _originalSpeeds = <TrackController, double>{};
  final _tuned = <TrackController>{};
  final _groups = <String, GroupSettings>{};
  final _appliedGroups = <TrackController, String?>{};
  final _listeners = <TrackController, VoidCallback>{};
  final _played = <TrackController>{};
  final _activity = <TrackController, int>{};
  var _frame = 0;
  String? _selectedGroup;
  MotorInspectionSubscription? _subscription;
  MotorDevToolsController? _ownedController;
  var _nextNumber = 1;
  var _refreshScheduled = false;
  Timer? _mutedPoll;
  var _muted = <TrackController>{};
  var _animating = <TrackController>{};

  /// The activity frame when idle controllers were last hidden.
  var _hiddenAt = 0;

  MotorDevToolsController get _overlay =>
      widget.controller ?? (_ownedController ??= MotorDevToolsController());

  @override
  void initState() {
    super.initState();
    if (kMotorDevTools) {
      _overlay.addListener(_scheduleRefresh);
      if (widget.enabled) _attach();
    }
  }

  @override
  void didUpdateWidget(MotorDevTools oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kMotorDevTools) _updateWidget(oldWidget);
  }

  void _updateWidget(MotorDevTools oldWidget) {
    if (!identical(oldWidget.controller, widget.controller)) {
      (oldWidget.controller ?? _ownedController)?.removeListener(
        _scheduleRefresh,
      );
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _overlay.addListener(_scheduleRefresh);
    }
    if (oldWidget.enabled != widget.enabled) {
      widget.enabled ? _attach() : _detach();
    }
    if (oldWidget.visible && !widget.visible) _resumeShown();
    _syncMutedPoll();
  }

  void _attach() {
    _subscription ??= MotorInspectionRegistry.attach(_Observer(this));
  }

  void _detach() {
    _restoreSession();
    _listeners
      ..forEach((controller, listener) => controller.removeListener(listener))
      ..clear();
    _subscription?.dispose();
    _subscription = null;
    _controllers.clear();
    _overlay.close();
    _syncMutedPoll();
  }

  /// Muting and finishing don't notify, so while the panel is open, check
  /// every controller's ticker now and then.
  void _syncMutedPoll() {
    if (_overlay.isOpen && widget.visible && _subscription != null) {
      _mutedPoll ??= Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _poll(),
      );
    } else {
      _mutedPoll?.cancel();
      _mutedPoll = null;
    }
  }

  void _poll() {
    final muted = {
      for (final controller in _controllers)
        if (controller.isMuted) controller,
    };
    final animating = {
      for (final controller in _controllers)
        if (controller.isAnimating) controller,
    };
    if (setEquals(muted, _muted) && setEquals(animating, _animating)) return;
    _muted = muted;
    _animating = animating;
    setState(() {});
  }

  void _scheduleRefresh() {
    if (!mounted || _refreshScheduled) return;
    _refreshScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (!mounted) return;
        _controllers.forEach(_syncGroup);
        _syncMutedPoll();
        setState(() {});
      })
      ..scheduleFrame();
  }

  void _register(TrackController controller) {
    if (controller.debugLabel == internalDebugLabel) return;
    if (_controllers.contains(controller)) return;
    _numbers[controller] = _nextNumber++;
    if (kDebugMode && controller.debugLabel == null) {
      _creations[controller] = StackTrace.current;
    }
    _controllers.add(controller);
    void listener() {
      if (!controller.isAnimating) return;
      _activity[controller] = ++_frame;
      if (_played.add(controller)) _scheduleRefresh();
    }

    _listeners[controller] = listener;
    controller.addListener(listener);
    _syncGroup(controller);
    _scheduleRefresh();
  }

  /// Applies the settings of [controller]'s group once it joins one.
  void _syncGroup(TrackController controller) {
    final group = controller.inspectionGroup;
    if (_appliedGroups.containsKey(controller) &&
        _appliedGroups[controller] == group) {
      return;
    }
    _appliedGroups[controller] = group;
    _applyGroup(controller, group == null ? null : _groups[group]);
  }

  void _applyGroup(TrackController controller, GroupSettings? settings) {
    if (settings?.speed case final speed?) setSpeed(controller, speed);
    final overrides = settings?.overrides ?? const <String?, Motion>{};
    if (overrides.isNotEmpty) _tuned.add(controller);
    controller.groupMotionOverride = overrides.isEmpty
        ? null
        : groupMotionResolver(controller, Map.of(overrides));
  }

  List<TrackController> _membersOf(String group) => [
    for (final controller in _controllers)
      if (controller.inspectionGroup == group) controller,
  ];

  void _unregister(TrackController controller) {
    if (!_controllers.remove(controller)) return;
    if (identical(_overlay.selectedController, controller)) {
      _overlay.showControllerList();
    }
    _originalSpeeds.remove(controller);
    _tuned.remove(controller);
    _creations.remove(controller);
    _guessedNames.remove(controller);
    _appliedGroups.remove(controller);
    _played.remove(controller);
    _activity.remove(controller);
    if (_listeners.remove(controller) case final listener?) {
      controller.removeListener(listener);
    }
    _scheduleRefresh();
  }

  @override
  List<TrackController> get controllers => List.unmodifiable(_controllers);

  @override
  Map<String, Motion> get appMotions => widget.motions;

  @override
  bool isIdle(TrackController controller) {
    if (controller.isAnimating || changesOf(controller).isNotEmpty) {
      return false;
    }
    final neverPlayed =
        !_played.contains(controller) &&
        controller.inspectPlayback().tracks.isEmpty;
    return neverPlayed || (_activity[controller] ?? 0) <= _hiddenAt;
  }

  @override
  void hideIdle() => setState(() => _hiddenAt = _frame);

  @override
  int lastActive(TrackController controller) => _activity[controller] ?? 0;

  @override
  GroupSettings settingsOf(String group) =>
      _groups.putIfAbsent(group, GroupSettings.new);

  @override
  List<String> changesOf(TrackController controller) {
    final original = _originalSpeeds[controller];
    final group = controller.inspectionGroup;
    final motions =
        controller.motionOverrides.length +
        (controller.hasGroupMotionOverride && group != null
            ? _groups[group]?.overrides.length ?? 0
            : 0);
    return [
      if (PlaybackState.of(controller) == PlaybackState.paused) 'Paused',
      if (original != null && controller.playbackSpeed != original)
        speedLabel(controller.playbackSpeed),
      if (motions == 1) '1 motion' else if (motions > 1) '$motions motions',
    ];
  }

  void _restoreSpeed(TrackController controller) {
    if (_originalSpeeds.remove(controller) case final speed?) {
      controller.playbackSpeed = speed;
    }
  }

  @override
  void reset(TrackController controller) {
    _restoreSpeed(controller);
    controller
      ..clearOwnMotionOverrides()
      ..resume();
    setState(() {});
  }

  @override
  void resetGroup(String group) {
    _groups.remove(group);
    for (final member in _membersOf(group)) {
      _restoreSpeed(member);
      member
        ..groupMotionOverride = null
        ..resume();
    }
    setState(() {});
  }

  @override
  void resetAll() {
    for (final controller in _controllers) {
      _restoreSpeed(controller);
      controller
        ..clearMotionOverrides()
        ..resume();
    }
    _originalSpeeds.clear();
    _tuned.clear();
    _groups.clear();
    setState(() {});
  }

  /// Resumes what the shown page paused: pausing and scrubbing last only
  /// while their page is open.
  void _resumeShown() {
    if (_overlay.selectedController case final controller?) {
      controller.resume();
    } else if (_selectedGroup case final group?) {
      for (final member in _membersOf(group)) {
        member.resume();
      }
    }
  }

  @override
  void setGroupSpeed(String group, double speed) {
    settingsOf(group).speed = speed;
    for (final member in _membersOf(group)) {
      setSpeed(member, speed);
    }
    setState(() {});
  }

  @override
  void setGroupOverride(
    String group,
    String? label,
    Motion? motion, {
    bool replay = true,
  }) {
    final settings = settingsOf(group);
    if (motion == null) {
      settings.overrides.remove(label);
    } else {
      settings.overrides[label] = motion;
    }
    for (final member in _membersOf(group)) {
      _applyGroup(member, settings);
      if (replay) member.replay();
    }
    setState(() {});
  }

  @override
  void showController(TrackController controller) {
    if (controller.inspectionGroup != _selectedGroup) _selectedGroup = null;
    _overlay.showController(controller);
  }

  @override
  void showGroup(String group) => setState(() => _selectedGroup = group);

  @override
  void back() {
    _resumeShown();
    if (_overlay.selectedController != null) {
      _overlay.showControllerList();
    } else {
      setState(() => _selectedGroup = null);
    }
  }

  @override
  void close() {
    _resumeShown();
    _overlay.close();
  }

  @override
  String baseNameOf(TrackController controller) => _baseNameOf(controller);

  String _baseNameOf(TrackController controller) =>
      controller.debugLabel ??
      _guessedNames.putIfAbsent(
        controller,
        () => guessControllerName(controller, _creations[controller]),
      ) ??
      'Controller ${_numbers[controller] ?? 0}';

  /// The display name, numbered when several controllers share a name.
  @override
  String nameOf(TrackController controller) {
    final name = _baseNameOf(controller);
    final same = [
      for (final other in _controllers)
        if (_baseNameOf(other) == name) other,
    ];
    if (same.length < 2) return name;
    return '$name ${same.indexOf(controller) + 1}';
  }

  @override
  void setSpeed(TrackController controller, double speed) {
    _originalSpeeds.putIfAbsent(controller, () => controller.playbackSpeed);
    controller.playbackSpeed = speed;
  }

  @override
  void setOverride(
    TrackController controller,
    Track<Object> track,
    Motion? motion, {
    bool replay = true,
  }) {
    _tuned.add(controller);
    controller.setMotionOverride(track, motion);
    if (replay) {
      controller.replay();
    } else {
      setState(() {});
    }
  }

  void _restoreSession() {
    for (final MapEntry(key: controller, value: speed)
        in _originalSpeeds.entries) {
      if (_controllers.contains(controller)) controller.playbackSpeed = speed;
    }
    for (final controller in _tuned) {
      if (_controllers.contains(controller)) controller.clearMotionOverrides();
    }
    _originalSpeeds.clear();
    _tuned.clear();
    _groups.clear();
    _appliedGroups.clear();
  }

  @override
  void dispose() {
    if (kMotorDevTools) {
      _restoreSession();
      _mutedPoll?.cancel();
      _listeners.forEach((controller, listener) {
        controller.removeListener(listener);
      });
      _subscription?.dispose();
      (widget.controller ?? _ownedController)?.removeListener(
        _scheduleRefresh,
      );
      _ownedController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kMotorDevTools) {
      // Always the same Stack with the app first, so switching the tools on
      // or off keeps the app's state.
      return Stack(
        fit: StackFit.passthrough,
        textDirection: TextDirection.ltr,
        children: [widget.child, if (widget.enabled) _buildOverlay()],
      );
    }
    return widget.child;
  }

  Widget _buildOverlay() {
    final selected = _overlay.selectedController;
    return Positioned.fill(
      // Hidden, the overlay keeps its state, such as the bubble's place
      // and the open page, but its tickers stop.
      child: Visibility(
        visible: widget.visible,
        maintainState: true,
        child: _Environment(
          child: FloatingBubble(
            isOpen: _overlay.isOpen,
            onOpen: () => _overlay.open(selected),
            initialAlignment: widget.alignment,
            activity: Listenable.merge(_controllers),
            isActive: () => _controllers.any((c) => c.isAnimating),
            modifiedCount: () => _controllers
                .where((c) => c.inspectable && changesOf(c).isNotEmpty)
                .length,
            panel: DevToolsPanel(
              host: this,
              group:
                  _selectedGroup != null &&
                      _membersOf(_selectedGroup!).isNotEmpty
                  ? _selectedGroup
                  : null,
              controller: _controllers.contains(selected) ? selected : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Observer implements MotorInspectionObserver {
  _Observer(this._state);

  final _MotorDevToolsState _state;

  @override
  void didRegisterController(TrackController controller) =>
      _state._register(controller);

  @override
  void didUnregisterController(TrackController controller) =>
      _state._unregister(controller);
}

/// Gives the overlay what it needs even above a `WidgetsApp`: media, text
/// direction, the platform brightness's palette, and unscaled text.
class _Environment extends StatelessWidget {
  const _Environment({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context) == null) {
      return MediaQuery.fromView(
        view: View.of(context),
        child: _Environment(child: child),
      );
    }
    final palette = DevToolsPalette.of(
      MediaQuery.platformBrightnessOf(context),
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DevToolsTheme(
          palette: palette,
          child: DefaultTextStyle(
            style: palette.body,
            child: child,
          ),
        ),
      ),
    );
  }
}
