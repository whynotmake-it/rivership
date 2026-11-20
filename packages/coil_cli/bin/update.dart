import 'dart:io';

import 'package:coil_cli/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await updateCommand(arguments);
}
