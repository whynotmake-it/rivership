import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:merging_dots/merging_dots.dart';

/// The body shapes of [BlobCharacter.build].
enum BlobBody {
  /// One round dot.
  round([SceneDot(50, 52, 32)], eyeY: 49, eyeGap: 14, eyeRadius: 12, blend: 16),

  /// Two dots side by side, wide like a pill.
  pill(
    [SceneDot(36, 54, 24), SceneDot(64, 54, 24)],
    eyeY: 51,
    eyeGap: 13,
    eyeRadius: 10.5,
    blend: 19,
  ),

  /// A small dot on a large one, like a bean standing up.
  bean(
    [SceneDot(50, 62, 28), SceneDot(50, 40, 24)],
    eyeY: 41,
    eyeGap: 11,
    eyeRadius: 9.5,
    blend: 22,
  ),

  /// Four dots in a square, melted into a soft squircle.
  squircle(
    [
      SceneDot(37, 38, 18),
      SceneDot(63, 38, 18),
      SceneDot(37, 64, 18),
      SceneDot(63, 64, 18),
    ],
    eyeY: 47,
    eyeGap: 13,
    eyeRadius: 11,
    blend: 25,
  ),

  /// A dome with a wavy hem.
  ghost(
    [
      SceneDot(50, 42, 28),
      SceneDot(50, 58, 26),
      SceneDot(30, 76, 9),
      SceneDot(50, 78, 9),
      SceneDot(70, 76, 9),
    ],
    eyeY: 41,
    eyeGap: 11,
    eyeRadius: 10,
    blend: 16,
  ),

  /// Low and soft, like a mochi.
  mochi(
    [SceneDot(50, 54, 26), SceneDot(30, 60, 20), SceneDot(70, 60, 20)],
    eyeY: 54,
    eyeGap: 12,
    eyeRadius: 9,
    blend: 19,
  );

  const BlobBody(
    this.dots, {
    required this.eyeY,
    required this.eyeGap,
    required this.eyeRadius,
    required this.blend,
  });

  /// The dots of the body on a 100 x 100 canvas.
  final List<SceneDot> dots;

  /// Where the eyes are.
  final double eyeY;

  /// How far each eye is from the middle.
  final double eyeGap;

  /// How large the eyes are.
  final double eyeRadius;

  /// How much the body's dots melt together.
  final double blend;
}

/// An example character built from merging dots.
abstract final class BlobCharacter {
  /// The most body dots of a [BlobBody].
  static const _bodySlots = 5;

  /// A blob that starts as three loading dots, melts into a body with two
  /// eyes and splits back into dots when it loads again.
  ///
  /// Its states:
  /// - `loading`: three dots hopping in turn.
  /// - `pulse`, `goo` and `orbit`: other loaders. The dots grow in turn,
  ///   melt into each other, or circle a ring in 3D.
  /// - `idle`: a face that breathes, blinks and looks around.
  /// - `happy`: hops twice with squinting eyes, then idles.
  /// - `surprised`: pops up with wide eyes, then idles.
  /// - `thinking`: looks up from side to side.
  /// - `sleepy`: eyes shut, breathing slowly.
  /// - `done`: the eyes stretch into a checkmark that swings in in 3D.
  /// - `error`: the eyes turn into an exclamation mark and it shakes.
  ///
  /// Its eyes invert the body, so they peek out as dots when they look
  /// past its edge. When it looks around, it turns its head in 3D: its eyes
  /// are balls on the front of a sphere around its body, so they slide
  /// further than the body and peek out past it.
  static DotCharacter build({BlobBody body = BlobBody.round, Color? color}) {
    const center = Offset(50, 52);
    // The head is a sphere around the body's dots.
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final dot in body.dots) {
      left = math.min(left, dot.x - dot.radius);
      top = math.min(top, dot.y - dot.radius);
      right = math.max(right, dot.x + dot.radius);
      bottom = math.max(bottom, dot.y + dot.radius);
    }
    final pivot = Offset((left + right) / 2, (top + bottom) / 2);
    final headRadius = math.max(right - left, bottom - top) / 2;
    // Eyes, lids and marks sit on the front of the head.
    SceneDot onHead(SceneDot dot) {
      if (dot.layer < 1) return dot;
      final at = dot.start + dot.stretch / 2 - pivot;
      final depth = math.sqrt(
        math.max(headRadius * headRadius - at.distanceSquared, 0),
      );
      return dot.copyWith(depth: depth);
    }

    // Dots 0 and 2 are the outer loading dots and the eyes, dot 1 the
    // middle loading dot and the body, then the rest of the body and the
    // eyelids: two upper ones, then two lower ones.
    DotScene scene({
      required SceneDot left,
      required SceneDot middle,
      required SceneDot right,
      List<SceneDot> rest = const [],
      List<SceneDot>? lids,
      double lidSquash = 1,
      SceneLayer bodyLayer = const SceneLayer(),
      SceneLayer eyes = const SceneLayer(blend: 2),
    }) => DotScene(
      pivot: pivot,
      layers: [
        bodyLayer,
        eyes,
        eyes.copyWith(squash: lidSquash),
      ],
      dots: [
        for (final dot in <SceneDot>[
          left,
          middle,
          right,
          for (var i = 0; i < _bodySlots - 1; i++)
            if (i < rest.length) rest[i] else SceneDot(center.dx, center.dy, 0),
          ...?lids,
          if (lids == null)
            for (var i = 0; i < 4; i++)
              SceneDot(i.isEven ? left.x : right.x, left.y, 0, layer: 2),
        ])
          onHead(dot),
      ],
    );

    DotScene face({
      SceneLayer eyes = const SceneLayer(blend: 2),
      double eyeScale = 1,
      Offset bodyOffset = Offset.zero,
      double bodySquash = 1,
      _Lids lids = _Lids.open,
      Offset turn = Offset.zero,
    }) {
      final r = body.eyeRadius * eyeScale;
      final y = body.eyeY;
      // Larger eyes move apart, so they don't melt into each other.
      final gap = body.eyeGap + (r - body.eyeRadius);
      // Open lids rest just outside the eyes, so they slide over them
      // from above or below instead of growing out of their middle.
      SceneDot upper(double x) => lids == _Lids.sleepy
          // A flat lid over the upper half: the eye droops.
          ? SceneDot(x, y - r * 0.5, r * 1.3, layer: 2)
          : SceneDot(x, y - r * 1.4, 0, layer: 2);
      SceneDot lower(double x) => lids == _Lids.happy
          // Covers the lower half: the eye smiles as an arc.
          ? SceneDot(x, y + r * 0.95, r * 1.15, layer: 2)
          : SceneDot(x, y + r * 1.4, 0, layer: 2);
      return scene(
        left: SceneDot(50 - gap, y, r, layer: 1),
        middle: body.dots.first,
        right: SceneDot(50 + gap, y, r, layer: 1),
        rest: body.dots.sublist(1),
        lids: [
          upper(50 - gap),
          upper(50 + gap),
          lower(50 - gap),
          lower(50 + gap),
        ],
        lidSquash: lids == _Lids.sleepy ? 0.5 : 1,
        bodyLayer: SceneLayer(
          blend: body.blend,
          offset: bodyOffset,
          squash: bodySquash,
          turn: turn,
        ),
        eyes: eyes.copyWith(offset: eyes.offset + bodyOffset, turn: turn),
      );
    }

    DotScene loadingPose(int? raised) {
      SceneDot dot(int i) =>
          SceneDot(30 + i * 20, raised == i ? 42 : 52, raised == i ? 9 : 8);
      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: const SceneLayer(blend: 4),
      );
    }

    // Three dots growing in turn.
    DotScene pulsePose(int big) {
      SceneDot dot(int i) => SceneDot(30 + i * 20, 52, big == i ? 10.5 : 6.5);
      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: const SceneLayer(blend: 9),
      );
    }

    // The middle dot swinging over to melt into each side.
    DotScene gooPose(double middle) => scene(
      left: const SceneDot(30, 52, 8),
      middle: SceneDot(middle, 52, 8),
      right: const SceneDot(70, 52, 8),
      bodyLayer: const SceneLayer(blend: 14),
    );

    // Three dots circling a ring tilted toward the viewer: the front ones
    // dip and grow, the back ones rise and shrink.
    const orbitSteps = 12;
    DotScene orbitPose(int step) {
      SceneDot dot(int i) {
        final angle = (step / orbitSteps + i / 3) * 2 * math.pi;
        final depth = math.sin(angle) * 20;
        return SceneDot(
          50 + math.cos(angle) * 20,
          52,
          7.5 + math.sin(angle) * 1.5,
          depth: depth,
        );
      }

      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: const SceneLayer(blend: 8, turn: Offset(0, -0.55)),
      );
    }

    final idle = face();

    // Strokes drawn with the eyes, around the middle of the face.
    final middleY = body.eyeY + 4;
    final check = (
      SceneDot.capsule(Offset(37, middleY), Offset(45, middleY + 9), 4.5),
      SceneDot.capsule(Offset(45, middleY + 9), Offset(63, middleY - 9), 4.5),
    );
    final exclamation = (
      SceneDot.capsule(Offset(50, middleY - 15), Offset(50, middleY + 3), 5),
      SceneDot(50, middleY + 14, 5.5),
    );
    // The face with its eyes turned into [strokes].
    DotScene mark(
      (SceneDot, SceneDot) strokes, {
      Offset bodyOffset = Offset.zero,
      Offset turn = Offset.zero,
    }) {
      final scene = face(bodyOffset: bodyOffset, turn: turn);
      return scene
          .withDot(0, onHead(strokes.$1.copyWith(layer: 1)))
          .withDot(2, onHead(strokes.$2.copyWith(layer: 1)));
    }

    const loaders = ['loading', 'pulse', 'goo', 'orbit'];
    const hop = CupertinoMotion(
      duration: Duration(milliseconds: 380),
      bounce: 0.3,
    );

    return DotCharacter(
      initial: 'loading',
      style: DotSceneStyle(
        layers: [
          DotLayerStyle(color: color),
          const DotLayerStyle.invert(edgeBlend: 3),
          DotLayerStyle(color: color, clipped: true),
        ],
      ),
      states: {
        'loading': CharacterState(
          DotSequence([
            for (var i = 0; i < 3; i++) DotKeyframe(loadingPose(i)),
            DotKeyframe(
              loadingPose(null),
              hold: const Duration(milliseconds: 120),
            ),
          ], motion: hop),
        ),
        'pulse': CharacterState(
          DotSequence(
            [for (var i = 0; i < 3; i++) DotKeyframe(pulsePose(i))],
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 320),
              bounce: 0.35,
            ),
          ),
        ),
        'goo': CharacterState(
          DotSequence(
            [
              DotKeyframe(gooPose(36), hold: const Duration(milliseconds: 80)),
              DotKeyframe(gooPose(64), hold: const Duration(milliseconds: 80)),
            ],
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 620),
              bounce: 0.2,
            ),
          ),
        ),
        'orbit': CharacterState(
          DotSequence([
            for (var step = 0; step < orbitSteps; step++)
              DotKeyframe(orbitPose(step)),
          ], motion: const Motion.linear(Duration(milliseconds: 95))),
        ),
        'idle': CharacterState.pose(
          idle,
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 600),
            bounce: 0.25,
          ),
          idles: const [
            DotIdle.breathe(),
            DotIdle.bob(amount: 1),
            DotIdle.blink(),
            DotIdle.lookAround(
              layers: [1, 2],
              range: Offset(4, 3),
              turn: Offset(0.42, 0.3),
            ),
          ],
        ),
        'happy': CharacterState(
          DotSequence(
            [
              for (var i = 0; i < 2; i++) ...[
                DotKeyframe(
                  face(
                    lids: _Lids.happy,
                    bodyOffset: const Offset(0, -8),
                    bodySquash: 1.04,
                  ),
                ),
                DotKeyframe(face(lids: _Lids.happy, bodySquash: 0.94)),
              ],
              DotKeyframe(idle, hold: const Duration(milliseconds: 200)),
            ],
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 320),
              bounce: 0.35,
            ),
            loop: LoopMode.none,
          ),
          idles: const [DotIdle.breathe()],
          next: 'idle',
        ),
        'surprised': CharacterState(
          DotSequence([
            DotKeyframe(
              face(
                eyeScale: 1.15,
                bodyOffset: const Offset(0, -4),
                bodySquash: 1.06,
              ),
              hold: const Duration(milliseconds: 900),
              motion: const CupertinoMotion(
                duration: Duration(milliseconds: 360),
                bounce: 0.45,
              ),
            ),
            DotKeyframe(idle),
          ], loop: LoopMode.none),
          idles: const [DotIdle.blink(interval: Duration(seconds: 6))],
          next: 'idle',
        ),
        'thinking': CharacterState(
          DotSequence(
            [
              DotKeyframe(
                face(eyes: const SceneLayer(blend: 2, offset: Offset(-7, -8))),
                hold: const Duration(milliseconds: 900),
              ),
              DotKeyframe(
                face(eyes: const SceneLayer(blend: 2, offset: Offset(8, -7))),
                hold: const Duration(milliseconds: 1100),
              ),
            ],
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 700),
              bounce: 0.1,
            ),
            loop: LoopMode.pingPong,
          ),
          idles: const [DotIdle.breathe(), DotIdle.blink()],
        ),
        'sleepy': CharacterState.pose(
          face(lids: _Lids.sleepy, bodySquash: 0.96),
          motion: const CupertinoMotion(duration: Duration(milliseconds: 900)),
          idles: const [
            DotIdle.breathe(amount: 0.04, period: Duration(milliseconds: 4600)),
            DotIdle.bob(period: Duration(milliseconds: 4600)),
          ],
        ),
        'done': CharacterState(
          DotSequence(
            [
              // The check swings in from the side in 3D, overshoots and
              // settles facing the front.
              DotKeyframe(
                mark(
                  check,
                  bodyOffset: const Offset(0, -6),
                  turn: const Offset(-0.75, 0.25),
                ),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 320),
                  bounce: 0.2,
                ),
              ),
              DotKeyframe(mark(check, turn: const Offset(0.32, -0.12))),
              DotKeyframe(
                mark(check),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 520),
                  bounce: 0.45,
                ),
              ),
            ],
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 380),
              bounce: 0.35,
            ),
            loop: LoopMode.none,
          ),
          idles: const [DotIdle.breathe()],
        ),
        'error': CharacterState(
          DotSequence(
            [
              DotKeyframe(
                mark(exclamation),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 360),
                  bounce: 0.2,
                ),
              ),
              for (final dx in [-5.0, 4.0, -3.0, 2.0, 0.0])
                DotKeyframe(mark(exclamation, bodyOffset: Offset(dx, 0))),
            ],
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 110),
            ),
            loop: LoopMode.none,
          ),
          idles: const [DotIdle.breathe()],
        ),
      },
      transitions: [
        // Loaders change into each other directly.
        for (final from in loaders)
          for (final to in loaders)
            if (from != to) CharacterTransition(from: from, to: to, via: []),
        for (final loader in loaders) ...[
          // Three dots melt into one blob, then the eyes open from its
          // middle as the next state starts.
          CharacterTransition(
            from: loader,
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 420),
              bounce: 0.15,
            ),
            via: [
              DotKeyframe(
                scene(
                  left: SceneDot(center.dx - 6, center.dy, 12),
                  middle: SceneDot(
                    center.dx,
                    center.dy,
                    body.dots.first.radius,
                  ),
                  right: SceneDot(center.dx + 6, center.dy, 12),
                  bodyLayer: const SceneLayer(blend: 18),
                ),
              ),
            ],
          ),
          // The eyes close into the body, which then splits into dots.
          CharacterTransition(
            to: loader,
            motion: const CupertinoMotion(
              duration: Duration(milliseconds: 380),
              bounce: 0.1,
            ),
            via: [
              DotKeyframe(
                scene(
                  left: SceneDot(center.dx - 10, center.dy, 13),
                  middle: SceneDot(center.dx, center.dy, 22),
                  right: SceneDot(center.dx + 10, center.dy, 13),
                  bodyLayer: const SceneLayer(blend: 18),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Where the eyelids of [BlobCharacter.build] are.
enum _Lids { open, happy, sleepy }
