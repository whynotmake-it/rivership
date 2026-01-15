import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  testWidgets(
    'tests all devices and orientations',
    variant: TestOnDevices(
      [
        Devices.ios.iPhone16Pro,
        Devices.ios.iPad,
        Devices.android.googlePixel9,
        Devices.android.largeTablet,
      ],
      orientations: {
        Orientation.portrait,
        Orientation.landscape,
      },
    ),
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox.expand(child: _TargetPlatformColor()),
          ),
        ),
      );
      await snap(matchToGolden: true);
    },
  );
}

class _TargetPlatformColor extends StatelessWidget {
  const _TargetPlatformColor();

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => const ColoredBox(color: Colors.blue),
      TargetPlatform.android => const ColoredBox(color: Colors.green),
      TargetPlatform.macOS => const ColoredBox(color: Colors.grey),
      TargetPlatform.windows => const ColoredBox(color: Colors.purple),
      TargetPlatform.linux => const ColoredBox(color: Colors.orange),
      _ => const ColoredBox(color: Colors.black),
    };
  }
}
