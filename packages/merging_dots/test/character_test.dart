import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DotShaders.precache);

  testWidgets('inverting eyes are holes in the body and dots outside it', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(
              dimension: 100,
              child: DotSceneView(
                scene: const DotScene(
                  layers: [SceneLayer(blend: 6), SceneLayer(blend: 2)],
                  dots: [
                    SceneDot(50, 50, 30),
                    // Inside the body.
                    SceneDot(60, 50, 8, layer: 1),
                    // Past its left edge.
                    SceneDot(12, 50, 6, layer: 1),
                  ],
                ),
                style: DotSceneStyle.face(color: const Color(0xFF000000)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(boundary.toImage))!;
    final data = (await tester.runAsync(image.toByteData))!;
    int alpha(int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);

    expect(alpha(40, 50), 255, reason: 'body');
    expect(alpha(60, 50), 0, reason: 'eye inside the body');
    expect(alpha(12, 50), 255, reason: 'eye outside the body');
    expect(alpha(90, 10), 0, reason: 'background');
    image.dispose();
  });

  group('DotCharacterController', () {
    late DotCharacterController controller;

    Future<void> start(WidgetTester tester, {String? state}) async {
      await tester.pumpWidget(
        _Host(
          onCreate: (vsync) => controller = DotCharacterController(
            vsync: vsync,
            character: _character,
            initialState: state,
            seed: 1,
          ),
        ),
      );
    }

    int eyesOn(DotScene scene) =>
        scene.dots.where((dot) => dot.layer == 1 && dot.radius > 0).length;

    testWidgets('melts loading dots into a face, and splits it again', (
      tester,
    ) async {
      await start(tester);
      expect(controller.state, 'dots');
      expect(eyesOn(controller.animator.target), 0);

      controller.goTo('face');
      expect(controller.isInTransition, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.isInTransition, isFalse);
      expect(eyesOn(controller.animator.target), 2);

      // Interrupt the way back halfway: the dots still end up loading.
      controller.goTo('dots');
      await tester.pump(const Duration(milliseconds: 100));
      controller
        ..goTo('face')
        ..goTo('dots');
      await tester.pump(const Duration(seconds: 2));
      expect(controller.state, 'dots');
      expect(controller.animator.isAnimating, isTrue);
      expect(eyesOn(controller.animator.target), 0);
    });

    testWidgets('one-shot states move on by themselves', (tester) async {
      final states = <String>[];
      await start(tester, state: 'face');
      controller
        ..onStateChanged = states.add
        ..goTo('cheer');
      await tester.pump(const Duration(seconds: 4));
      expect(states, ['cheer', 'face']);
      expect(controller.state, 'face');
    });

    testWidgets('idles blink and look around on top of the pose', (
      tester,
    ) async {
      await start(tester, state: 'face');
      final layers = Float32List(2 * DotScene.stride);
      var blinked = false;
      var looked = false;
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        layers
          ..fillRange(0, layers.length, 0)
          ..setRange(0, layers.length, controller.animator.values);
        controller.modifyLayers(layers, 2);
        const eyes = DotScene.stride;
        if (layers[eyes + 4] < 0.5) blinked = true;
        if (layers[eyes + 2].abs() > 2) looked = true;
      }
      expect(blinked, isTrue);
      expect(looked, isTrue);

      controller.lookAt(const Offset(1, 0));
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      layers.setRange(0, layers.length, controller.animator.values);
      controller.modifyLayers(layers, 2);
      expect(layers[DotScene.stride + 2], greaterThan(4));
    });
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.onCreate});

  final DotCharacterController Function(TickerProvider vsync) onCreate;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final DotCharacterController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.onCreate(this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

DotScene _dots(int raised) => DotScene(
  layers: const [SceneLayer(blend: 6), SceneLayer(blend: 2)],
  dots: [
    for (var i = 0; i < 3; i++) SceneDot(30 + i * 20, raised == i ? 42 : 52, 8),
  ],
);

DotScene _face({double hop = 0}) => DotScene(
  layers: [
    SceneLayer(blend: 10, offset: Offset(0, hop)),
    SceneLayer(blend: 2, offset: Offset(0, hop)),
  ],
  dots: const [
    SceneDot(36, 48, 11, layer: 1),
    SceneDot(50, 52, 32),
    SceneDot(64, 48, 11, layer: 1),
  ],
);

/// Three loading dots that melt into a face with two eyes.
final _character = DotCharacter(
  initial: 'dots',
  style: DotSceneStyle.face(),
  states: {
    'dots': CharacterState(
      DotSequence([for (var i = 0; i < 3; i++) DotKeyframe(_dots(i))]),
    ),
    'face': CharacterState.pose(
      _face(),
      idles: const [DotIdle.breathe(), DotIdle.blink(), DotIdle.lookAround()],
    ),
    'cheer': CharacterState(
      DotSequence([
        DotKeyframe(_face(hop: -8)),
        DotKeyframe(_face()),
      ], loop: LoopMode.none),
      next: 'face',
    ),
  },
  transitions: const [
    CharacterTransition(
      from: 'dots',
      via: [
        DotKeyframe(
          DotScene(
            layers: [SceneLayer(blend: 18), SceneLayer(blend: 2)],
            dots: [
              SceneDot(44, 52, 12),
              SceneDot(50, 52, 28),
              SceneDot(56, 52, 12),
            ],
          ),
        ),
      ],
    ),
  ],
);
