import 'package:flutter/painting.dart';
import 'package:merging_dots/merging_dots.dart';

/// The body shapes of [BlobCharacter.build].
enum BlobBody {
  /// One round dot.
  round([SceneDot(50, 52, 32)], eyeY: 49, eyeGap: 14, eyeRadius: 12, blend: 10),

  /// Two dots side by side, wide like a pill.
  pill(
    [SceneDot(36, 54, 24), SceneDot(64, 54, 24)],
    eyeY: 51,
    eyeGap: 13,
    eyeRadius: 10.5,
    blend: 12,
  ),

  /// A small dot on a large one, like a bean standing up.
  bean(
    [SceneDot(50, 62, 28), SceneDot(50, 40, 24)],
    eyeY: 41,
    eyeGap: 11,
    eyeRadius: 9.5,
    blend: 14,
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
    blend: 16,
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
    blend: 10,
  ),

  /// Low and soft, like a mochi.
  mochi(
    [SceneDot(50, 54, 26), SceneDot(30, 60, 20), SceneDot(70, 60, 20)],
    eyeY: 54,
    eyeGap: 12,
    eyeRadius: 9,
    blend: 12,
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
  /// - `idle`: a face that breathes, blinks and looks around.
  /// - `happy`: hops twice with squinting eyes, then idles.
  /// - `surprised`: pops up with wide eyes, then idles.
  /// - `thinking`: looks up from side to side.
  /// - `sleepy`: eyes shut, breathing slowly.
  ///
  /// Its eyes invert the body, so they peek out as dots when they look
  /// past its edge.
  static DotCharacter build({BlobBody body = BlobBody.round, Color? color}) {
    const center = Offset(50, 52);
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
      layers: [
        bodyLayer,
        eyes,
        eyes.copyWith(squash: lidSquash),
      ],
      dots: [
        left,
        middle,
        right,
        for (var i = 0; i < _bodySlots - 1; i++)
          if (i < rest.length) rest[i] else SceneDot(center.dx, center.dy, 0),
        ...?lids,
        if (lids == null)
          for (var i = 0; i < 4; i++)
            SceneDot(i.isEven ? left.x : right.x, left.y, 0, layer: 2),
      ],
    );

    DotScene face({
      SceneLayer eyes = const SceneLayer(blend: 2),
      double eyeScale = 1,
      Offset bodyOffset = Offset.zero,
      double bodySquash = 1,
      _Lids lids = _Lids.open,
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
        ),
        eyes: eyes.copyWith(offset: eyes.offset + bodyOffset),
      );
    }

    DotScene loadingPose(int? raised) {
      SceneDot dot(int i) =>
          SceneDot(30 + i * 20, raised == i ? 42 : 52, raised == i ? 9 : 8);
      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: const SceneLayer(blend: 7),
      );
    }

    final idle = face();
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
          DotLayerStyle(color: color),
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
            DotIdle.lookAround(layers: [1, 2]),
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
      },
      transitions: [
        // Three dots melt into one blob, then the eyes open from its
        // middle as the next state starts.
        CharacterTransition(
          from: 'loading',
          motion: const CupertinoMotion(
            duration: Duration(milliseconds: 420),
            bounce: 0.15,
          ),
          via: [
            DotKeyframe(
              scene(
                left: SceneDot(center.dx - 6, center.dy, 12),
                middle: SceneDot(center.dx, center.dy, body.dots.first.radius),
                right: SceneDot(center.dx + 6, center.dy, 12),
                bodyLayer: const SceneLayer(blend: 18),
              ),
            ),
          ],
        ),
        // The eyes close into the body, which then splits into dots.
        CharacterTransition(
          to: 'loading',
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
    );
  }
}

/// Where the eyelids of [BlobCharacter.build] are.
enum _Lids { open, happy, sleepy }
