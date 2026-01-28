import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/motor.dart';

bool _debugMotorEnabled = false;
DebugMotorRegistry? _debugMotorRegistry;

/// Enables or disables motor debugging globally.
// ignore: avoid_positional_boolean_parameters
set debugMotor(bool value) {
  _debugMotorEnabled = value;
  if (value) {
    _debugMotorRegistry ??= DebugMotorRegistry();
  } else {
    _debugMotorRegistry?.dispose();
    _debugMotorRegistry = null;
  }
}

/// Whether motor debugging is enabled globally.
bool get debugMotor => _debugMotorEnabled;

/// A widget that can be used to track the instantiation and disposal of
/// [MotionController]s across an app for debugging purposes.
class DebugMotorRegistry extends ChangeNotifier {
  /// The [DebugMotorRegistry] widget.
  static DebugMotorRegistry? get instance => _debugMotorRegistry;

  final Set<MotionController> _controllers = {};

  /// The currently registered controllers.
  Set<MotionController> get controllers => Set.unmodifiable(_controllers);

  /// Registers a [MotionController].
  void registerController(MotionController controller) {
    _controllers.add(controller);
    notifyListeners();
  }

  /// Unregisters a [MotionController].
  void unregisterController(MotionController controller) {
    _controllers.remove(controller);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        super.notifyListeners();
      });
      return;
    }

    super.notifyListeners();
  }
}

class MotorDebug extends StatelessWidget {
  const MotorDebug({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Stack(
        children: [
          child,
          if (DebugMotorRegistry.instance case final registry?)
            Positioned(
              right: 16,
              bottom: 16,
              child: _MotionControllerList(
                registry: DebugMotorRegistry.instance!,
              ),
            ),
        ],
      ),
    );
  }
}

class _MotionControllerList extends StatelessWidget {
  const _MotionControllerList({
    required this.registry,
    super.key,
  });

  final DebugMotorRegistry registry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: registry,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motion Controllers (${registry.controllers.length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                ...registry.controllers.map((controller) {
                  return ListenableBuilder(
                    listenable: controller,
                    builder: (context, child) {
                      return Text(
                        controller.toString(),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          );
        });
  }
}
