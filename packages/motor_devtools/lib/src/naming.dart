import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/style.dart';

/// Guesses a name for a controller without a `debugLabel`, in debug builds.
///
/// Controllers made by motor's builders are named after the widget that
/// built the builder, such as `CardStack · SingleMotionBuilder`. Others are
/// named after the code that created them, read from [creation], such as
/// `PaymentSuccessPage · controller`.
String? guessControllerName(TrackController controller, StackTrace? creation) {
  if (!kDebugMode) return null;
  if (controller.debugCreator case final Element element) {
    return _nameFromElement(element);
  }
  return creation == null ? null : _nameFromStack(creation);
}

/// A name for a track without a `debugLabel`: its value type and first
/// steps in debug builds, such as `Offset: to (0.0, 24.0) → sync`.
String guessTrackName(TrackPlayback playback, int index) {
  if (!kDebugMode) return 'Track ${index + 1}';
  final type = _typeArgument(playback.track.runtimeType.toString());
  final steps = playback.hasSyntheticReturnStep
      ? playback.steps.take(playback.steps.length - 1)
      : playback.steps;
  final summary = [
    for (final step in steps.take(3)) _describeStep(step),
    if (steps.length > 3) '…',
  ].join(' → ');
  return summary.isEmpty ? type : '$type: $summary';
}

String _describeStep(TrackStep<Object> step) => switch (step) {
  StepTo(:final value) => 'to ${formatValue(value)}',
  StepAt(:final at, :final value) =>
    'at ${formatDuration(at)} ${formatValue(value)}',
  StepHold(:final duration) => 'hold ${formatDuration(duration)}',
  StepSync() => 'sync',
  StepFree() => 'free',
};

String? _nameFromElement(Element builder) {
  final builderType = _typeName(builder.widget.runtimeType.toString());
  String? owner;
  var built = builder;
  builder.visitAncestorElements((ancestor) {
    if ((ancestor is StatelessElement || ancestor is StatefulElement) &&
        debugIsWidgetLocalCreation(built.widget)) {
      owner = _typeName(ancestor.widget.runtimeType.toString());
      return false;
    }
    built = ancestor;
    return true;
  });
  return owner == null ? builderType : '$owner · $builderType';
}

const _skippedPackages = {'motor', 'motor_devtools', 'flutter'};
const _lifecycleMethods = {
  'initState',
  'didChangeDependencies',
  'didUpdateWidget',
  'build',
  'new',
  '<anonymous closure>',
};

String? _nameFromStack(StackTrace creation) {
  for (final frame in StackFrame.fromStackTrace(creation)) {
    if (frame.packageScheme == 'dart' ||
        _skippedPackages.contains(frame.package)) {
      continue;
    }
    final owner = frame.className == '<unknown>' || frame.className.isEmpty
        ? _fromFileName(frame.packagePath)
        : _typeName(frame.className, stripState: true);
    final member = _memberName(frame.method);
    if (owner == null) return null;
    return member == null ? owner : '$owner · $member';
  }
  return null;
}

String? _memberName(String method) {
  final name = method
      .replaceFirst(RegExp('^(get|set) '), '')
      .split('.')
      .last
      .replaceAll(RegExp(r'[\[\]]'), '')
      .replaceFirst(RegExp('^_+'), '');
  if (name.isEmpty || _lifecycleMethods.contains(name)) return null;
  return name;
}

String? _fromFileName(String path) {
  final file = path.split('/').last.replaceFirst(RegExp(r'\.dart$'), '');
  if (file.isEmpty || file == '<unknown>') return null;
  return file
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

/// `_Foo<int>` → `Foo`; with [stripState], `_FooState` → `Foo`.
String _typeName(String type, {bool stripState = false}) {
  var name = type.split('<').first.replaceFirst(RegExp('^_+'), '');
  if (stripState && name.length > 5 && name.endsWith('State')) {
    name = name.substring(0, name.length - 'State'.length);
  }
  return name;
}

String _typeArgument(String type) {
  final start = type.indexOf('<');
  if (start < 0 || !type.endsWith('>')) return 'value';
  return type.substring(start + 1, type.length - 1);
}
