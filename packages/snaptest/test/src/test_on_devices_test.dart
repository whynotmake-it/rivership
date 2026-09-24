import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  final tested = <(DeviceInfo, Orientation)>{};

  final variant = TestDevicesVariant(
    {
      Devices.ios.iPhone16Pro,
      Devices.ios.iPad,
      Devices.android.googlePixel9,
      Devices.android.largeTablet,
    },
    orientations: {
      Orientation.portrait,
      Orientation.landscape,
    },
  );

  tearDownAll(() {
    expect(tested, containsAllInOrder(variant.values));
  });

  testWidgets(
    'tests all devices and orientations',
    variant: variant,
    (tester) async {
      final (device, orientation) = variant.currentValue!;
      final expectedSize = orientation == Orientation.landscape
          ? device.screenSize.flipped
          : device.screenSize;

      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox.expand(child: _TargetPlatformColor()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.renderViews.single.size, expectedSize);
      tested.add(variant.currentValue!);
      await snap.andGolden(
        settings: const SnaptestSettings.rendered(),
      );
      expect(
        tester.binding.renderViews.single.size,
        expectedSize,
        reason: 'capturing inside an active variant must preserve its viewport',
      );
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
