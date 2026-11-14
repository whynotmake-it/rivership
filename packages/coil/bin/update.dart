import 'dart:io';

import 'package:coil/src/eject/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await updateCommand(arguments);
}
