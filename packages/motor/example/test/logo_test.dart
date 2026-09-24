import 'dart:io';

import 'package:example_design/example_design.dart' show LogoTile;
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/widgets/motor_logo.dart';
import 'package:motor_example/widgets/style.dart';

void main() {
  testWidgets('build motor logo for README', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = .dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    const key = ValueKey('motor_logo');
    const dpr = 4.0;
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: LogoTile(
            color: Palette.dark.surface,
            border: Palette.dark.border,
            shadow: const Color(0x80000000),
            scale: dpr,
            child: const SizedBox.square(
              dimension: 56 * dpr,
              child: Center(child: MotorLogo(size: 23 * dpr)),
            ),
          ),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: .png);
      return data!.buffer.asUint8List();
    });
    File('../doc/logo.png').writeAsBytesSync(png!);
  });
}
