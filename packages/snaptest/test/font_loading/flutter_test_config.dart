import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:snaptest/src/flutter_sdk_root.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  final font = File(
    '${flutterSdkRoot().path}/bin/cache/artifacts/'
    'material_fonts/Roboto-Regular.ttf',
  ).readAsBytesSync();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final asset = utf8.decode(message!.buffer.asUint8List());
        if (asset == 'FontManifest.json') {
          return ByteData.sublistView(
            Uint8List.fromList(
              utf8.encode(
                jsonEncode([
                  {
                    'family': 'packages/fixture/PackageFont',
                    'fonts': [
                      {'asset': 'packages/fixture/Roboto-Regular.ttf'},
                    ],
                  },
                ]),
              ),
            ),
          );
        }
        if (asset == 'packages/fixture/Roboto-Regular.ttf') {
          return ByteData.sublistView(font);
        }
        return null;
      });
  // Exercise the first font load in the test, not in the parent suite's setup.
  await testMain();
}
