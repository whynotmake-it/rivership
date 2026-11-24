import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
  static DotCharacter build({
    BlobBody body = BlobBody.round,
    Color? color,
    BlobTuning tuning = const BlobTuning(),
  }) {
    final t = tuning;
    final eyes0 = SceneLayer(blend: t.eyeBlend);
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
      return dot.copyWith(depth: depth * t.eyeDepth);
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
      SceneLayer? eyes,
    }) => DotScene(
      pivot: pivot,
      layers: [
        bodyLayer,
        eyes ?? eyes0,
        (eyes ?? eyes0).copyWith(squash: lidSquash),
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
      SceneLayer? eyes,
      double eyeScale = 1,
      Offset bodyOffset = Offset.zero,
      double bodySquash = 1,
      _Lids lids = _Lids.open,
      Offset turn = Offset.zero,
    }) {
      final base = body.eyeRadius * t.eyeSize;
      final r = base * eyeScale;
      final y = body.eyeY;
      // Larger eyes move apart, so they don't melt into each other.
      final gap = body.eyeGap * t.eyeSpacing + (r - base);
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
          blend: body.blend * t.bodyBlend,
          offset: bodyOffset,
          squash: bodySquash,
          turn: turn,
        ),
        eyes: (eyes ?? eyes0).copyWith(
          offset: (eyes ?? eyes0).offset + bodyOffset,
          turn: turn,
        ),
      );
    }

    DotScene loadingPose(int? raised) {
      SceneDot dot(int i) =>
          SceneDot(30 + i * 20, raised == i ? 42 : 52, raised == i ? 9 : 8);
      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: SceneLayer(blend: t.loadingBlend),
      );
    }

    // Three dots growing in turn.
    DotScene pulsePose(int big) {
      SceneDot dot(int i) => SceneDot(30 + i * 20, 52, big == i ? 10.5 : 6.5);
      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: SceneLayer(blend: t.pulseBlend),
      );
    }

    // Three dots in a row, with the outer ones moved and grown: the
    // middle one plunges into a side, which it pushes outward.
    DotScene gooPose(
      double middle, {
      double left = 30,
      double right = 70,
      double leftRadius = 8,
      double rightRadius = 8,
    }) => scene(
      left: SceneDot(left, 52, leftRadius),
      middle: SceneDot(middle, 52, 8),
      right: SceneDot(right, 52, rightRadius),
      bodyLayer: SceneLayer(blend: t.gooBlend),
    );

    // Three dots circling a ring tilted toward the viewer: the front ones
    // dip and grow, the back ones rise and shrink. In 3D, the ring has
    // depth and the blend fades between dots far apart in it, so they
    // crease where they pass. Flat, it is laid out as the ellipse it
    // looks like, and the dots stay softly joined all the way round.
    const orbitSteps = 12;
    DotScene orbitPose(int step) {
      SceneDot dot(int i) {
        final angle = (step / orbitSteps + i / 3) * 2 * math.pi;
        final front = math.sin(angle);
        final size = t.orbitDotSize * (1 + front * 0.2);
        final x = 50 + math.cos(angle) * t.orbitRadius;
        if (t.orbit3d) {
          return SceneDot(x, 52, size, depth: front * t.orbitRadius);
        }
        return SceneDot(
          x,
          52 + front * t.orbitRadius * math.sin(t.orbitTilt),
          size,
        );
      }

      return scene(
        left: dot(0),
        middle: dot(1),
        right: dot(2),
        bodyLayer: SceneLayer(
          blend: t.orbitBlend,
          turn: t.orbit3d ? Offset(0, -t.orbitTilt) : Offset.zero,
        ),
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
          DotLayerStyle.invert(edgeBlend: t.eyeEdge),
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
        // The middle dot plunges into a side, pushing it outward so it
        // swells, the two recoil, and the side spits it back out toward
        // the other one.
        'goo': CharacterState(
          DotSequence([
            for (final side in [1.0, -1.0]) ...[
              // Plunges in, fully.
              DotKeyframe(
                gooPose(50 + 20 * side),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 300),
                ),
              ),
              // Carries the side outward, which swells.
              DotKeyframe(
                gooPose(
                  50 + (20 + t.gooPush) * side,
                  left: side < 0 ? 30 - t.gooPush : 30,
                  right: side > 0 ? 70 + t.gooPush : 70,
                  leftRadius: side < 0 ? 8 * t.gooSwell : 8,
                  rightRadius: side > 0 ? 8 * t.gooSwell : 8,
                ),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 240),
                  bounce: 0.3,
                ),
              ),
              // Recoils together.
              DotKeyframe(
                gooPose(50 + 19 * side),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 280),
                  bounce: 0.3,
                ),
              ),
              // Spits it back out.
              DotKeyframe(
                gooPose(50),
                hold: const Duration(milliseconds: 60),
                motion: const CupertinoMotion(
                  duration: Duration(milliseconds: 420),
                  bounce: 0.2,
                ),
              ),
            ],
          ]),
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
          idles: [
            const DotIdle.breathe(),
            const DotIdle.bob(amount: 1),
            const DotIdle.blink(),
            DotIdle.lookAround(
              layers: const [1, 2],
              range: const Offset(4, 3),
              turn: t.turn,
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
                face(eyes: eyes0.copyWith(offset: const Offset(-7, -8))),
                hold: const Duration(milliseconds: 900),
              ),
              DotKeyframe(
                face(eyes: eyes0.copyWith(offset: const Offset(8, -7))),
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

/// The look of [BlobCharacter.build], to prototype with.
@immutable
class BlobTuning {
  /// Creates a tuning. The defaults are the blob's look.
  const BlobTuning({
    this.bodyBlend = 1,
    this.eyeSize = 1,
    this.eyeSpacing = 1,
    this.eyeBlend = 2,
    this.eyeEdge = 3,
    this.eyeDepth = 1,
    this.turn = const Offset(0.42, 0.3),
    this.loadingBlend = 4,
    this.pulseBlend = 9,
    this.gooBlend = 8,
    this.gooPush = 7,
    this.gooSwell = 1.19,
    this.orbitBlend = 20,
    this.orbitRadius = 15,
    this.orbitTilt = 0.55,
    this.orbitDotSize = 8,
    this.orbit3d = true,
  });

  /// Scales how much the body's dots melt together.
  final double bodyBlend;

  /// Scales the eyes.
  final double eyeSize;

  /// Scales how far apart the eyes are.
  final double eyeSpacing;

  /// How much the eyes melt into each other.
  final double eyeBlend;

  /// How round the corners are where the eyes cross the body's edge.
  final double eyeEdge;

  /// Scales how far the eyes sit in front of the head, which sets how much
  /// further than the body they move when it turns.
  final double eyeDepth;

  /// How far the head turns when looking around, in radians.
  final Offset turn;

  /// How much the hopping loading dots melt together.
  final double loadingBlend;

  /// How much the pulsing dots melt together.
  final double pulseBlend;

  /// How much the goo dots melt together.
  final double gooBlend;

  /// How far the goo's moving dot pushes the side it plunges into.
  final double gooPush;

  /// How much the pushed side swells, as a factor of its size.
  final double gooSwell;

  /// How much the orbiting dots melt together.
  final double orbitBlend;

  /// The radius of the orbit's ring.
  final double orbitRadius;

  /// How far the ring tilts toward the viewer, in radians.
  final double orbitTilt;

  /// How large the orbiting dots are.
  final double orbitDotSize;

  /// Whether the orbit turns in 3D, where dots far apart in depth crease
  /// instead of melting, or is laid out flat and stays joined.
  final bool orbit3d;

  /// A copy with the given fields replaced.
  BlobTuning copyWith({
    double? bodyBlend,
    double? eyeSize,
    double? eyeSpacing,
    double? eyeBlend,
    double? eyeEdge,
    double? eyeDepth,
    Offset? turn,
    double? loadingBlend,
    double? pulseBlend,
    double? gooBlend,
    double? gooPush,
    double? gooSwell,
    double? orbitBlend,
    double? orbitRadius,
    double? orbitTilt,
    double? orbitDotSize,
    bool? orbit3d,
  }) => BlobTuning(
    bodyBlend: bodyBlend ?? this.bodyBlend,
    eyeSize: eyeSize ?? this.eyeSize,
    eyeSpacing: eyeSpacing ?? this.eyeSpacing,
    eyeBlend: eyeBlend ?? this.eyeBlend,
    eyeEdge: eyeEdge ?? this.eyeEdge,
    eyeDepth: eyeDepth ?? this.eyeDepth,
    turn: turn ?? this.turn,
    loadingBlend: loadingBlend ?? this.loadingBlend,
    pulseBlend: pulseBlend ?? this.pulseBlend,
    gooBlend: gooBlend ?? this.gooBlend,
    gooPush: gooPush ?? this.gooPush,
    gooSwell: gooSwell ?? this.gooSwell,
    orbitBlend: orbitBlend ?? this.orbitBlend,
    orbitRadius: orbitRadius ?? this.orbitRadius,
    orbitTilt: orbitTilt ?? this.orbitTilt,
    orbitDotSize: orbitDotSize ?? this.orbitDotSize,
    orbit3d: orbit3d ?? this.orbit3d,
  );

  /// This tuning as Dart code, to paste as new defaults.
  String toDart() {
    String n(double v) => v.toStringAsFixed(2);
    return 'BlobTuning(\n'
        '  bodyBlend: ${n(bodyBlend)},\n'
        '  eyeSize: ${n(eyeSize)},\n'
        '  eyeSpacing: ${n(eyeSpacing)},\n'
        '  eyeBlend: ${n(eyeBlend)},\n'
        '  eyeEdge: ${n(eyeEdge)},\n'
        '  eyeDepth: ${n(eyeDepth)},\n'
        '  turn: Offset(${n(turn.dx)}, ${n(turn.dy)}),\n'
        '  loadingBlend: ${n(loadingBlend)},\n'
        '  pulseBlend: ${n(pulseBlend)},\n'
        '  gooBlend: ${n(gooBlend)},\n'
        '  gooPush: ${n(gooPush)},\n'
        '  gooSwell: ${n(gooSwell)},\n'
        '  orbitBlend: ${n(orbitBlend)},\n'
        '  orbitRadius: ${n(orbitRadius)},\n'
        '  orbitTilt: ${n(orbitTilt)},\n'
        '  orbitDotSize: ${n(orbitDotSize)},\n'
        '  orbit3d: $orbit3d,\n'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      other is BlobTuning && other.toDart() == toDart();

  @override
  int get hashCode => toDart().hashCode;
}
