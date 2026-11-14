import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/flag.dart';
import 'package:motor_devtools/src/naming.dart';
import 'package:motor_devtools/src/overlay.dart';
import 'package:motor_devtools/src/panel.dart';
import 'package:motor_devtools/src/session.dart';
import 'package:motor_devtools/src/style.dart';

/// Opens and closes the [MotorDevTools] panel from code.
///
/// Disabling the tools with [MotorDevTools.enabled] closes the panel. While
/// they are disabled, the panel isn't shown, whatever [isOpen] says.
class MotorDevToolsController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the panel is open rather than folded into the bubble.
  bool get isOpen => _isOpen;

  /// Opens the panel on the page it showed last.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Folds the panel back into the bubble.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Opens the panel if it is closed, and closes it if it is open.
  void toggle() => _isOpen ? close() : open();
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
///   builder: (context, child) => MotorDevTools(child: child!),
/// )
/// ```
///
/// Controllers are listed by their `debugLabel`, which `TrackController`,
/// `MotionController`, and motor's builder widgets accept.
///
/// Three switches, from coarsest to finest:
///
/// - [kMotorDevTools] compiles the tools in or out of a build.
/// - [enabled] turns tracking on or off at runtime. It defaults to
///   [kDebugMode], so release builds do nothing unless it is true. When
///   false, only the child is rendered, Motor's inspection registry is not
///   attached, and the session's changes are undone.
/// - [visible] shows or hides the overlay while tracking goes on, keeping
///   the controllers found so far and every change, such as for a debug
///   menu that opens the tools when needed.
class MotorDevTools extends StatefulWidget {
  /// Creates an optional Motor developer overlay.
  const MotorDevTools({
    required this.child,
    this.enabled = kDebugMode,
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

  /// Whether the tools track controllers. Defaults to [kDebugMode]; pass
  /// true to ship the tools in a release build. See [MotorDevTools] for how
  /// this differs from [visible].
  final bool enabled;

  /// Whether the overlay is shown while [enabled]. Hiding it keeps tracking
  /// and all changes; pausing and scrubbing resume, as when the panel is
  /// minimized.
  final bool visible;

  /// Opens and closes the panel from code. The tools create their own when
  /// this is null.
  final MotorDevToolsController? controller;

  /// Where the bubble starts. `x` picks the left or right edge; `y` sets the
  /// height.
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
  final _statusListeners = <TrackController, AnimationStatusListener>{};
  final _played = <TrackController>{};
  final _activity = <TrackController, int>{};

  /// Controllers the tools paused or scrubbed, as opposed to the app.
  final _held = <TrackController>{};
  var _frame = 0;

  /// The page the panel shows. A controller opened from its group's page
  /// keeps the group, so going back returns to it.
  ({String? group, TrackController? controller}) _page = _listPage;

  static const _listPage = (group: null, controller: null);

  /// Whether the panel was open at the last controller notification.
  var _wasOpen = false;
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
      _overlay.addListener(_overlayChanged);
      _wasOpen = _overlay.isOpen;
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
        _overlayChanged,
      );
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _overlay.addListener(_overlayChanged);
      _wasOpen = _overlay.isOpen;
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
    _statusListeners
      ..forEach((controller, listener) {
        controller.removeStatusListener(listener);
      })
      ..clear();
    _subscription?.dispose();
    _subscription = null;
    _controllers.clear();
    _numbers.clear();
    _creations.clear();
    _guessedNames.clear();
    _played.clear();
    _activity.clear();
    _muted.clear();
    _animating.clear();
    _page = _listPage;
    _syncMutedPoll();
    // The controller may belong to the app, which can listen to it above
    // these tools, so close it after this build rather than during it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.enabled) _overlay.close();
    });
  }

  /// Muting and settling don't notify, so while the panel is open, check
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

  void _overlayChanged() {
    final isOpen = _overlay.isOpen;
    // Pausing and scrubbing last only while the panel is open.
    if (_wasOpen && !isOpen) _resumeShown();
    _wasOpen = isOpen;
    _scheduleRefresh();
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
      _held.remove(controller);
      _activity[controller] = ++_frame;
      if (_played.add(controller)) _scheduleRefresh();
    }

    void statusListener(AnimationStatus _) => _scheduleRefresh();

    _listeners[controller] = listener;
    _statusListeners[controller] = statusListener;
    controller
      ..addListener(listener)
      ..addStatusListener(statusListener);
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

  /// Applies a group's [settings] to [controller], and clears a group motion
  /// the tools set before. A controller the tools never touched keeps
  /// whatever other tooling set on it.
  void _applyGroup(TrackController controller, GroupSettings? settings) {
    if (settings?.speed case final speed?) setSpeed(controller, speed);
    final overrides = settings?.overrides ?? const <String?, Motion>{};
    if (overrides.isNotEmpty) {
      _tuned.add(controller);
      controller.groupMotionOverride = groupMotionResolver(
        controller,
        Map.of(overrides),
      );
    } else if (controller.hasGroupMotionOverride) {
      controller.groupMotionOverride = null;
    }
  }

  List<TrackController> _membersOf(String group) => [
    for (final controller in _controllers)
      if (controller.inspectionGroup == group) controller,
  ];

  void _unregister(TrackController controller) {
    if (!_controllers.remove(controller)) return;
    if (identical(_page.controller, controller)) {
      _page = (group: _page.group, controller: null);
    }
    _originalSpeeds.remove(controller);
    _tuned.remove(controller);
    _numbers.remove(controller);
    _creations.remove(controller);
    _guessedNames.remove(controller);
    _appliedGroups.remove(controller);
    _played.remove(controller);
    _activity.remove(controller);
    _muted.remove(controller);
    _animating.remove(controller);
    _held.remove(controller);
    if (_listeners.remove(controller) case final listener?) {
      controller.removeListener(listener);
    }
    if (_statusListeners.remove(controller) case final listener?) {
      controller.removeStatusListener(listener);
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
      if (_held.contains(controller) &&
          PlaybackState.of(controller) == PlaybackState.paused)
        'Paused',
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
  void notePause(TrackController controller) {
    _held.add(controller);
    setState(() {});
  }

  /// Resumes [controller] if the tools paused it.
  void _release(TrackController controller) {
    if (_held.remove(controller)) controller.resume();
  }

  @override
  void reset(TrackController controller) {
    _restoreSpeed(controller);
    controller.clearOwnMotionOverrides();
    _release(controller);
    setState(() {});
  }

  @override
  void resetGroup(String group) {
    _groups.remove(group);
    for (final member in _membersOf(group)) {
      _restoreSpeed(member);
      member.groupMotionOverride = null;
      _release(member);
    }
    setState(() {});
  }

  @override
  void resetAll() {
    for (final controller in _controllers) {
      _restoreSpeed(controller);
      controller.clearMotionOverrides();
      _release(controller);
    }
    _originalSpeeds.clear();
    _tuned.clear();
    _groups.clear();
    setState(() {});
  }

  /// Resumes what the shown page paused: pausing and scrubbing last only
  /// while their page is open.
  void _resumeShown() {
    if (_page.controller case final controller?) {
      _release(controller);
    } else if (_page.group case final group?) {
      _membersOf(group).forEach(_release);
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
    final group = controller.inspectionGroup;
    setState(() {
      _page = (
        group: group == _page.group ? group : null,
        controller: controller,
      );
    });
  }

  @override
  void showGroup(String group) =>
      setState(() => _page = (group: group, controller: null));

  @override
  void back() {
    _resumeShown();
    setState(() {
      _page = _page.controller != null
          ? (group: _page.group, controller: null)
          : _listPage;
    });
  }

  @override
  void close() => _overlay.close();

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
    // Resuming notifies, which updates _held.
    for (final controller in _held.toList()) {
      if (_controllers.contains(controller)) controller.resume();
    }
    _originalSpeeds.clear();
    _tuned.clear();
    _held.clear();
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
      _statusListeners.forEach((controller, listener) {
        controller.removeStatusListener(listener);
      });
      _subscription?.dispose();
      (widget.controller ?? _ownedController)?.removeListener(
        _overlayChanged,
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
    final (:group, controller: selected) = _page;
    return Positioned.fill(
      // Hidden, the overlay keeps its state, such as the bubble's place
      // and the open page, but its tickers stop and the panel isn't built.
      child: Visibility(
        visible: widget.visible,
        maintainState: true,
        child: _Environment(
          child: FloatingBubble(
            isOpen: _overlay.isOpen,
            onOpen: _overlay.open,
            initialAlignment: widget.alignment,
            // Computed when the tools rebuild, such as when a controller
            // starts or stops, never per frame, and not at all while hidden.
            isActive: widget.visible && _controllers.any((c) => c.isAnimating),
            modifiedCount: widget.visible
                ? _controllers
                      .where((c) => c.inspectable && changesOf(c).isNotEmpty)
                      .length
                : 0,
            panel: widget.visible
                ? CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): close,
                    },
                    // Takes focus when the panel opens, so the keyboard
                    // reaches its controls and Escape closes it.
                    child: FocusScope(
                      autofocus: true,
                      child: DevToolsPanel(
                        host: this,
                        group: group != null && _membersOf(group).isNotEmpty
                            ? group
                            : null,
                        controller: _controllers.contains(selected)
                            ? selected
                            : null,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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
/// direction, the platform brightness's palette, and text that scales up to
/// [_maxTextScale].
class _Environment extends StatelessWidget {
  const _Environment({required this.child});

  /// The largest text scale the panel's fixed-height rows fit.
  static const _maxTextScale = 1.3;

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
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: _maxTextScale),
      ),
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
