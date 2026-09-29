import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:motor_benchmark/motor_benchmark.dart';

/// Runs the suite in a compiled app (release or profile), then exits.
///
/// See `tool/run_aot.sh`.
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  var code = 0;
  try {
    final results = await runFromEnvironment(binding);
    if (results.any((r) => !r.equivalent)) code = 2;
  } on Object catch (error, stack) {
    stderr.writeln('$error\n$stack');
    code = 1;
  }
  exit(code);
}
