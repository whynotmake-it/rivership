import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/overlay.dart';
import 'package:motor_devtools/src/panel.dart';
import 'package:motor_devtools/src/session.dart';
import 'package:motor_devtools/src/style.dart';

/// Whether Motor DevTools are compiled into the app.
///
/// Build with `--dart-define=MOTOR_DEVTOOLS=false` to remove the tools and
/// motor's inspection hooks from the app entirely. [MotorDevTools] then
/// returns its child.
const bool kMotorDevTools = bool.fromEnvironment(
  'MOTOR_DEVTOOLS',
  defaultValue: true,
);

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
/// [enabled] switches the tools on and off at runtime, also in production
/// builds. When false, the child is returned directly and Motor's inspection
/// registry is not attached. To remove the tools from a build, see
/// [kMotorDevTools].
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

  /// Whether controller discovery and the overlay are enabled.
  final bool enabled;

  /// An optional imperative overlay controller.
  final MotorDevToolsController? controller;

  /// Where the bubble starts out.
  final Alignment alignment;

  @override
  State<MotorDevTools> createState() => _MotorDevToolsState();
}

class _MotorDevToolsState extends State<MotorDevTools> {
  final _controllers = <TrackController>[];
  final _numbers = <TrackController, int>{};
  final _originalSpeeds = <TrackController, double>{};
  final _tuned = <TrackController>{};
  MotorInspectionSubscription? _subscription;
  MotorDevToolsController? _ownedController;
  var _nextNumber = 1;
  var _refreshScheduled = false;

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
  }

  void _attach() {
    _subscription ??= MotorInspectionRegistry.attach(_Observer(this));
  }

  void _detach() {
    _restoreSession();
    _subscription?.dispose();
    _subscription = null;
    _controllers.clear();
    _overlay.close();
  }

  void _scheduleRefresh() {
    if (!mounted || _refreshScheduled) return;
    _refreshScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (mounted) setState(() {});
      })
      ..scheduleFrame();
  }

  void _register(TrackController controller) {
    if (controller.debugLabel == internalDebugLabel) return;
    if (_controllers.contains(controller)) return;
    _numbers[controller] = _nextNumber++;
    _controllers.add(controller);
    _scheduleRefresh();
  }

  void _unregister(TrackController controller) {
    if (!_controllers.remove(controller)) return;
    if (identical(_overlay.selectedController, controller)) {
      _overlay.showControllerList();
    }
    _originalSpeeds.remove(controller);
    _tuned.remove(controller);
    _scheduleRefresh();
  }

  String _nameOf(TrackController controller) =>
      controller.debugLabel ?? 'Controller ${_numbers[controller] ?? 0}';

  void _setSpeed(TrackController controller, double speed) {
    _originalSpeeds.putIfAbsent(controller, () => controller.playbackSpeed);
    controller.playbackSpeed = speed;
  }

  void _setOverride(
    TrackController controller,
    Track<Object> track,
    Motion? motion,
  ) {
    _tuned.add(controller);
    controller
      ..setMotionOverride(track, motion)
      ..replay();
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
  }

  @override
  void dispose() {
    if (kMotorDevTools) {
      _restoreSession();
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
      if (widget.enabled) return _buildTools();
    }
    return widget.child;
  }

  Widget _buildTools() {
    final selected = _overlay.selectedController;
    return Stack(
      fit: StackFit.passthrough,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned.fill(
          child: _Environment(
            child: FloatingBubble(
              isOpen: _overlay.isOpen,
              onOpen: () => _overlay.open(selected),
              initialAlignment: widget.alignment,
              activity: Listenable.merge(_controllers),
              isActive: () => _controllers.any((c) => c.isAnimating),
              panel: DevToolsPanel(
                controllers: List.unmodifiable(_controllers),
                selected: _controllers.contains(selected) ? selected : null,
                nameOf: _nameOf,
                onSelect: _overlay.showController,
                onBack: _overlay.showControllerList,
                onClose: _overlay.close,
                onSpeedChanged: _setSpeed,
                onOverrideChanged: _setOverride,
              ),
            ),
          ),
        ),
      ],
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
