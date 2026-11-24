@Tags(['showcase'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/character/blob_character.dart';
import 'package:snaptest/snaptest.dart';

/// Where the README's media go: `packages/merging_dots/doc`, relative to
/// this file.
const _doc = '../../../doc';

const _paper = Color(0xFFF3F1EC);
const _ink = Color(0xFF1D1C1A);

const _video = SnapVideoSettings(
  timing: VideoTiming.smooth,
  frameRate: 30,
  encoding: VideoEncoding.h264(crf: 16),
  pathPrefix: _doc,
  finalHold: Duration(milliseconds: 300),
);

DotCharacter _blob(BlobBody body) => BlobCharacter.build(body: body);

void main() {
  setUpAll(DotShaders.precache);

  testWidgets('character', (tester) async {
    // 1080 x 1080 pixels.
    tester.view
      ..physicalSize = const Size(1080, 1080)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final stage = GlobalKey<_StageState>();
    await tester.pumpWidget(_Stage(key: stage));
    final recording = await snap.recordVideo(
      name: 'character',
      settings: _video,
    );
    final state = stage.currentState!;
    final controller = state.controller;

    Future<void> scene(String caption, Duration duration) async {
      state.caption = caption;
      await tester.pump(duration);
    }

    const second = Duration(seconds: 1);

    // Loaders.
    await scene('loading', second * 2.2);
    controller.goTo('pulse');
    await scene('pulse', second * 2);
    controller.goTo('goo');
    await scene('goo', second * 2.4);
    controller.goTo('orbit');
    await scene('orbit in 3d', second * 2.6);

    // It wakes up and looks around, turning its head in 3D.
    controller.goTo('idle');
    await scene('wakes up', second * 2);
    for (final look in [
      const Offset(1, -0.2),
      const Offset(-1, 0.1),
      const Offset(0.6, -1),
      const Offset(-0.7, 1),
      const Offset(0, 0),
    ]) {
      controller.lookAt(look);
      await scene('turns in 3d', second * 0.9);
    }
    controller.lookAt(null);

    // Morphs between bodies, still alive.
    for (final body in [
      BlobBody.pill,
      BlobBody.bean,
      BlobBody.squircle,
      BlobBody.ghost,
      BlobBody.mochi,
      BlobBody.round,
    ]) {
      controller.character = _blob(body);
      await scene('morphs', second * 1.2);
    }

    // Moods.
    controller.goTo('happy');
    await scene('happy', second * 2);
    controller.goTo('surprised');
    await scene('surprised', second * 1.8);
    controller.goTo('sleepy');
    await scene('sleepy', second * 2);

    // Results.
    controller.goTo('done');
    await scene('done', second * 2.2);
    controller.goTo('error');
    await scene('error', second * 2.2);
    controller.goTo('loading');
    await scene('and back', second * 2);

    // The loaders that come with the package.
    state.showLoaders = true;
    await scene('+ ${DotLoaders.all.length} loaders', second * 4);

    await recording.stop();
    // Rendering 1,300 frames of 1080 x 1080 on the CPU takes a while.
  }, timeout: const Timeout(Duration(minutes: 45)));
}

class _Stage extends StatefulWidget {
  const _Stage({super.key});

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> with FixedTickerProviderStateMixin {
  late final DotCharacterController controller = DotCharacterController(
    vsync: this,
    character: _blob(BlobBody.round),
    seed: 4,
  );

  String _caption = '';
  set caption(String value) => setState(() => _caption = value);

  bool _showLoaders = false;
  set showLoaders(bool value) => setState(() => _showLoaders = value);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaders = [
      for (final loader in DotLoaders.all)
        if (!loader.isDeterminate) loader,
    ];
    final picks = [
      for (var i = 0; i < 9; i++) loaders[(i * loaders.length) ~/ 9],
    ];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _paper,
        child: IconTheme(
          data: const IconThemeData(color: _ink),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 50, 60, 90),
                  child: _showLoaders
                      ? Column(
                          children: [
                            for (var row = 0; row < 3; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (var column = 0; column < 3; column++)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(22),
                                          child: DotLoaderView(
                                            loader: picks[row * 3 + column],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : DotCharacterView(
                          character: controller.character,
                          controller: controller,
                        ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Text(
                  _caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 18,
                    letterSpacing: 1.5,
                    color: Color(0xFF6E6A63),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
