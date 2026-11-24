import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  testWidgets(
    'a custom overlay follows a mouse through hover, click and release, '
    'keeping its state for the whole recording',
    (tester) async {
      var clicks = 0;
      await tester.pumpWidget(_App(onPressed: () => clicks++));
      final button = tester.getCenter(find.text('Click me'));

      final frames = <SnapVideoFrame>[];
      final states = <State>{};
      final recording = await snap.recordVideo(
        name: 'overlay_probe',
        settings: SnapVideoSettings(
          minimumPointerDuration: const Duration(milliseconds: 400),
          overlay: (context, frame) => _Probe(
            frame: frame,
            onBuild: (state) {
              states.add(state);
              frames.add(frame);
            },
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: button - const Offset(60, 0));
      await mouse.moveTo(button - const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.moveTo(button);
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.down(button);
      await tester.pump(const Duration(milliseconds: 100));
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 100));
      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 300));
      await recording.stop();

      // The click reached the app: the overlay is not in its way.
      expect(clicks, 1);

      final view = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(frames, isNotEmpty);
      expect(frames.map((f) => f.size), everyElement(view));
      final elapsed = frames.map((f) => f.elapsed).toList();
      expect(elapsed, orderedEquals([...elapsed]..sort()));

      // The mouse is the only pointer: absent when recording starts, then
      // hovering → pressed → released → gone.
      final phases = <SnapPointerPhase?>[];
      for (final frame in frames) {
        expect(frame.pointers.length, lessThanOrEqualTo(1));
        final pointer = frame.pointers.firstOrNull;
        expect(pointer?.kind, anyOf(isNull, PointerDeviceKind.mouse));
        final phase = pointer?.phase;
        if (phases.isEmpty || phases.last != phase) phases.add(phase);
      }
      expect(phases, [
        null,
        SnapPointerPhase.hovering,
        SnapPointerPhase.pressed,
        SnapPointerPhase.released,
        null,
      ]);

      final pressed = frames
          .expand((f) => f.pointers)
          .where((p) => p.phase == SnapPointerPhase.pressed);
      expect(pressed.map((p) => p.position), everyElement(button));
      // Hover follows the mouse before the click.
      final hovering = frames
          .expand((f) => f.pointers)
          .where((p) => p.phase == SnapPointerPhase.hovering)
          .map((p) => p.position)
          .toSet();
      expect(hovering, containsAll([button - const Offset(30, 0), button]));

      expect(states, hasLength(1));
    },
  );

  testWidgets('the overlay leaves the app untouched', (tester) async {
    Future<List<Uint8List>> recordApp({required bool overlay}) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('app'),
          child: _App(onPressed: () {}),
        ),
      );
      final images = <Uint8List>[];
      Future<void> grab() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('app')),
        );
        images.add(
          (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.rawStraightRgba,
              );
              return data!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!,
        );
      }

      final recording = await snap.recordVideo(
        name: 'overlay_untouched_$overlay',
        settings: SnapVideoSettings(
          overlay: overlay ? SnapPointerOverlay.builder : null,
          minimumPointerDuration: const Duration(milliseconds: 200),
        ),
      );
      final button = tester.getCenter(find.text('Click me'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: button - const Offset(40, 0));
      await mouse.moveTo(button);
      await tester.pump(const Duration(milliseconds: 50));
      await grab();
      await mouse.down(button);
      await tester.pump(const Duration(milliseconds: 50));
      await grab();
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      await grab();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      await grab();
      await recording.stop();
      return images;
    }

    final without = await recordApp(overlay: false);
    final withOverlay = await recordApp(overlay: true);
    expect(withOverlay, hasLength(without.length));
    for (var i = 0; i < without.length; i++) {
      expect(withOverlay[i], orderedEquals(without[i]), reason: 'frame $i');
    }
  });

  testWidgets('a recording with the default overlay settles', (tester) async {
    await tester.pumpWidget(_App(onPressed: () {}));
    final recording = await snap.recordVideo(
      name: 'overlay_settles',
      settings: const SnapVideoSettings(
        overlay: SnapPointerOverlay.builder,
        minimumPointerDuration: Duration(milliseconds: 150),
      ),
    );
    final button = tester.getCenter(find.text('Click me'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: button - const Offset(40, 0));
    await mouse.moveTo(button);
    await tester.pump();
    await tester.tapAt(button);
    await tester.drag(find.text('Click me'), const Offset(0, 80));
    await mouse.down(button);
    await tester.pump(const Duration(milliseconds: 30));
    await mouse.up();
    await tester.pumpAndSettle();
    // It settled on its own, not because a limit stopped the recording and
    // its overlay.
    expect(recording.wasTruncated, isFalse);
    final video = await recording.stop();
    expect(video.existsSync(), isTrue);
  });
}

class _App extends StatelessWidget {
  const _App({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: onPressed,
          child: const Text('Click me'),
        ),
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.frame, required this.onBuild});

  final SnapVideoFrame frame;
  final void Function(State state) onBuild;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(this);
    return const SizedBox.expand();
  }
}
