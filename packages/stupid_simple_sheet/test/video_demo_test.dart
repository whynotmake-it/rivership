import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
  testWidgets(
    'demo video — sheet open, scroll, drag-to-dismiss',
    (tester) async {
      final recording = await snap.recordVideo(
        name: 'demo_sheet_drag',
        settings: const SnapVideoSettings(
          timing: VideoTiming.smooth,
          includeDeviceFrame: true,
          finalHold: Duration(milliseconds: 400),
        ),
      );

      await tester.pumpWidget(const _SheetDemoApp());
      await tester.pump(const Duration(milliseconds: 600));

      // Tap the button to present the sheet.
      await tester.tap(find.byKey(const ValueKey('open-sheet')));
      await tester.pump(const Duration(seconds: 1));

      // Scroll inside the sheet's list.
      await tester.fling(
        find.byKey(const ValueKey('sheet-list')),
        const Offset(0, -300),
        1200,
      );
      await tester.pump(const Duration(seconds: 1));

      // Drag the sheet down from its handle area.
      await tester.drag(
        find.byKey(const ValueKey('sheet-content')),
        const Offset(0, 400),
      );
      await tester.pump(const Duration(seconds: 1));

      final file = await recording.stop();
      expect(file.existsSync(), isTrue);
      // ignore: avoid_print
      print('Demo video (sheet): ${file.path}');
    },
    variant: TestDevicesVariant({Devices.ios.iPhone16Pro}),
  );
}

class _SheetDemoApp extends StatelessWidget {
  const _SheetDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Stupid Simple Sheet')),
        body: Center(
          child: Builder(
            builder: (context) {
              return FilledButton.icon(
                key: const ValueKey('open-sheet'),
                onPressed: () => Navigator.of(context).push(
                  StupidSimpleSheetRoute<void>(
                    child: const _SheetContent(),
                  ),
                ),
                icon: const Icon(Icons.vertical_split),
                label: const Text('Open sheet'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('sheet-content'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sheet'),
      ),
      body: ListView.builder(
        key: const ValueKey('sheet-list'),
        itemCount: 40,
        itemBuilder: (context, index) => ListTile(
          leading: CircleAvatar(child: Text('$index')),
          title: Text('Row $index'),
          subtitle: const Text('Scroll or drag me'),
        ),
      ),
    );
  }
}
