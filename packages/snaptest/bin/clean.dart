// ignore_for_file: avoid_print

import 'dart:io';

import 'package:snaptest/src/clean.dart';
import 'package:snaptest/src/constants.dart';

import 'package:snaptest/src/util.dart';

Future<void> main(List<String> args) async {
  try {
    final dirName = args.isNotEmpty ? args[0] : kDefaultSnaptestDir;
    final deleted = await internalCleanSnapshots(
      getTopLevelSnapDir(dirName),
      dirName,
    );

    if (deleted == 0) {
      print('No snapshots found to clean.');
    } else {
      print('Cleaned snapshots from $deleted locations');
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
