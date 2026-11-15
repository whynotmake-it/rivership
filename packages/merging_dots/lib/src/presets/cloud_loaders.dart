import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/presets/dot_loader.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:motor/motor.dart';

/// Endless freeform loaders: dots placed freely on a canvas that melt into
/// each other as they move.
///
/// Every loader is sampled from a periodic motion, so its last pose flows
/// back into its first one and the loop never shows a seam. Every pose has
/// the same dots in the same order, so dots glide instead of popping.
abstract final class CloudLoaders {
  /// A planet with two moons on crossing, tilted orbits, the inner one
  /// lapping the outer one; both melt into the planet as they pass it.
  static DotLoader get moons => _periodic(
    name: 'Moons',
    description:
        'Two moons on crossing, tilted orbits melt into their planet every '
        'time they pass it.',
    steps: 40,
    blend: 10,
    pose: (t) {
      final angle = 2 * math.pi * t;
      Dot moon({
        required double angle,
        required double tilt,
        required double reach,
        required double radius,
      }) {
        final depth = math.sin(angle);
        final dx = math.cos(angle) * reach;
        final dy = depth * reach * 0.32;
        return Dot(
          50 + dx * math.cos(tilt) - dy * math.sin(tilt),
          50 + dx * math.sin(tilt) + dy * math.cos(tilt),
          radius * (1 + 0.3 * depth),
        );
      }

      return [
        const Dot(50, 50, 14),
        moon(angle: angle, tilt: -0.5, reach: 40, radius: 7.5),
        moon(angle: -2 * angle + 1, tilt: 0.55, reach: 28, radius: 5),
      ];
    },
  );

  /// A blob that pinches into two, which drift apart and melt back
  /// together, each split turned a quarter from the last.
  static DotLoader get mitosis => _periodic(
    name: 'Mitosis',
    description:
        'A blob pinches into two cells that drift apart and melt back '
        'together, each split a quarter turn from the last.',
    steps: 32,
    blend: 14,
    pose: (t) {
      // 0 when merged, 1 when split, lingering at both ends.
      final split = _smoothstep(0.1, 0.9, math.sin(math.pi * t));
      final axis = math.pi / 4 + math.pi / 2 * t;
      final distance = 34 * split;
      final radius = 20 - 6 * split;
      final offset = Offset(math.cos(axis), math.sin(axis)) * distance / 2;
      return [
        Dot(50 + offset.dx, 50 + offset.dy, radius),
        Dot(50 - offset.dx, 50 - offset.dy, radius),
      ];
    },
  );

  /// A Newton's cradle: the outer balls take turns swinging out and
  /// knocking back into the row.
  static DotLoader get cradle => _periodic(
    name: 'Cradle',
    description:
        "A Newton's cradle whose outer balls take turns swinging out and "
        'knocking back into the row.',
    steps: 36,
    size: const Size(140, 56),
    blend: 5,
    pose: (t) {
      const count = 4;
      const radius = 10.0;
      const pitch = 2 * radius;
      const length = 32.0;
      const pivotY = 6.0;
      const amplitude = 0.8;
      final swing = math.sin(2 * math.pi * t);
      return [
        for (var i = 0; i < count; i++)
          () {
            final pivotX = 70 + (i - (count - 1) / 2) * pitch;
            final angle = switch (i) {
              0 => -amplitude * math.max(0, -swing),
              const (count - 1) => amplitude * math.max(0, swing),
              _ => 0.0,
            };
            return Dot(
              pivotX + length * math.sin(angle),
              pivotY + length * math.cos(angle),
              radius,
            );
          }(),
      ];
    },
  );

  /// Two gooey comets racing around a figure eight, melting into one blob
  /// every time they cross in the middle.
  static DotLoader get infinity => _periodic(
    name: 'Infinity',
    description:
        'Two gooey comets race around a figure eight and melt into one '
        'blob every time they cross in the middle.',
    steps: 40,
    blend: 10,
    pose: (t) {
      const tail = [9.0, 7.5, 6.0, 4.5];
      Offset at(double t) {
        final angle = 2 * math.pi * t;
        return Offset(
          50 + 38 * math.sin(angle),
          50 + 22 * math.sin(angle) * math.cos(angle) * 2,
        );
      }

      return [
        for (final start in const [0.0, 0.5])
          for (var i = 0; i < tail.length; i++)
            () {
              final position = at(t + start - i * 0.03);
              return Dot(position.dx, position.dy, tail[i]);
            }(),
      ];
    },
  );

  /// A drop swells under a tap, lets go, and splashes into a pool.
  static DotLoader get drip => _periodic(
    name: 'Drip',
    description:
        'A drop swells under a tap, lets go, and splashes into the pool '
        'below.',
    steps: 50,
    blend: 10,
    pose: (t) {
      const tapY = 8.0;
      const poolY = 86.0;
      const release = 0.42;
      const impact = 0.62;
      // The drop swells and sags under the tap, then falls with gravity.
      final Dot drop;
      if (t < release) {
        final swell = _smoothstep(0.02, release, t);
        drop = Dot(50, tapY + 4 + 12 * swell, 9 * math.sqrt(swell));
      } else if (t < impact) {
        final fall = (t - release) / (impact - release);
        drop = Dot(50, tapY + 16 + (poolY - tapY - 16) * fall * fall, 9);
      } else {
        final sink = _smoothstep(impact, impact + 0.08, t);
        drop = Dot(50, poolY + 2 * sink, 9 * (1 - sink));
      }

      // The pool's middle bobs up after the drop lands.
      final since = t - impact;
      final wobble = since < 0
          ? 0.0
          : math.sin(since * 24) * math.exp(-since * 9);
      Dot splash(double side) {
        const flight = 0.24;
        final progress = (since / flight).clamp(0.0, 1.0);
        if (since < 0 || progress >= 1) return Dot(50 + side * 6, poolY, 0);
        return Dot(
          50 + side * (8 + 26 * progress),
          poolY - 6 - 30 * 4 * progress * (1 - progress),
          4.5 * math.sin(math.pi * math.sqrt(progress)),
        );
      }

      return [
        const Dot(50, tapY, 7),
        drop,
        const Dot(28, poolY + 2, 11),
        Dot(50, poolY - 4 * wobble, 13 + 2 * wobble),
        const Dot(72, poolY + 2, 11),
        splash(-1),
        splash(1),
      ];
    },
  );

  /// A ball bouncing on the spot, stretching as it falls and squashing
  /// flat when it lands.
  static DotLoader get bounce => _periodic(
    name: 'Bounce',
    description:
        'A ball bounces on the spot, stretching as it falls and squashing '
        'flat when it lands.',
    steps: 30,
    step: const Duration(milliseconds: 32),
    blend: 6,
    pose: (t) {
      const radius = 13.0;
      const floor = 94.0;
      const height = 56.0;
      const contact = 0.2;
      // Squash while touching the floor, around t = 0.
      final contactProgress = ((t + contact / 2) % 1) / contact;
      final squash = contactProgress < 1
          ? math.sin(math.pi * contactProgress)
          : 0.0;
      // A parabola in the air, stretched along its speed.
      final air = ((t - contact / 2) / (1 - contact)).clamp(0.0, 1.0);
      final lift = 4 * air * (1 - air);
      final speed = (1 - 2 * air).abs();
      final stretch = speed * speed * (1 - squash);
      final y = floor - radius * (1 - 0.35 * squash) - height * lift;
      final sideRadius = 10 - 2 * stretch;
      Dot side(double sign) => Dot(
        50 + sign * 15 * squash,
        y + 6 * squash + sign * 10 * stretch,
        sideRadius,
      );
      return [Dot(50, y, radius * (1 - 0.2 * squash)), side(-1), side(1)];
    },
  );

  /// Three balls juggled in a cascade, each one melting into the hand
  /// that catches it.
  static DotLoader get juggle => _periodic(
    name: 'Juggle',
    description:
        'Two hands juggle three balls in a cascade, each ball melting into '
        'the hand that catches it.',
    steps: 48,
    blend: 8,
    pose: (t) {
      const handY = 74.0;
      const height = 54.0;
      const flight = 0.35;
      const carry = 0.5 - flight;
      // One hand's path, from catching out wide to throwing near the
      // middle, mirrored by [side].
      Offset carried(double side, double progress) => Offset(
        50 + side * (36 - 26 * progress),
        handY + 10 * math.sin(math.pi * progress),
      );
      Offset thrown(double side, double progress) => Offset(
        50 + side * (10 - 46 * progress),
        handY - height * 4 * progress * (1 - progress),
      );
      // A ball flies from the right hand to the left, rides it inwards,
      // then flies to the right and rides that hand back.
      Dot ball(double phase) {
        final u = (t + phase) % 1;
        final position = u < flight
            ? thrown(1, u / flight)
            : u < 0.5
            ? carried(-1, (u - flight) / carry)
            : u < 0.5 + flight
            ? thrown(-1, (u - 0.5) / flight)
            : carried(1, (u - 0.5 - flight) / carry);
        return Dot(position.dx, position.dy, 8);
      }

      // Each hand catches three times a loop, scooping a ball inwards and
      // swinging back out empty.
      Dot hand(double side, double start) {
        final h = ((t - start) * 3) % 1;
        const busy = carry * 3;
        final Offset position;
        if (h < busy) {
          position = carried(side, h / busy) + const Offset(0, 9);
        } else {
          final back = (h - busy) / (1 - busy);
          position = Offset(
            50 + side * (10 + 26 * back),
            handY + 9 - 6 * math.sin(math.pi * back),
          );
        }
        return Dot(position.dx, position.dy, 6);
      }

      return [
        for (var i = 0; i < 3; i++) ball(i / 3),
        hand(-1, flight),
        hand(1, 0.5 + flight),
      ];
    },
  );

  /// Blobs of wax drifting up and down a lamp, melting into each other and
  /// into the pool at the bottom.
  static DotLoader get lavaLamp => _periodic(
    name: 'Lava lamp',
    description:
        'Blobs of wax drift up and down a lamp, melting into each other and '
        'into the pool at the bottom.',
    steps: 64,
    size: const Size(64, 100),
    blend: 12,
    pose: (t) {
      final angle = 2 * math.pi * t;
      Dot blob(double radius, int rise, double phase, double sway) => Dot(
        32 + sway * math.sin(angle * rise + phase * 2),
        48 - 34 * math.cos(angle * rise + phase),
        radius,
      );
      return [
        Dot(32, 85, 14 + 1.5 * math.sin(angle * 2)),
        blob(10, 1, 0, 7),
        blob(8, 1, 2.4, 9),
        blob(7, 2, 4.2, 6),
        blob(5.5, 1, 4.4, 10),
      ];
    },
  );

  /// A comet on an elliptic orbit, whipping around its sun and coasting
  /// slowly back, its tail growing as it nears the sun.
  static DotLoader get comet => _periodic(
    name: 'Comet',
    description:
        'A comet whips around its sun and coasts slowly back, its gooey '
        'tail streaming away from the sun as it passes.',
    steps: 48,
    blend: 9,
    pose: (t) {
      const eccentricity = 0.55;
      const semiMajor = 30.0;
      final semiMinor = semiMajor * math.sqrt(1 - eccentricity * eccentricity);
      // The orbit lies along the diagonal, the longest line in the
      // canvas, with the sun placed so the long tail fits at both ends.
      const sunAlong = 10.5;
      const centerAlong = sunAlong - semiMajor * eccentricity;
      const tilt = -math.pi / 4;
      Offset place(double along, double across) => Offset(
        50 + along * math.cos(tilt) - across * math.sin(tilt),
        50 + along * math.sin(tilt) + across * math.cos(tilt),
      );
      final sun = place(sunAlong, 0);
      // Solve Kepler's equation for the eccentric anomaly, starting at
      // the far end of the orbit.
      final mean = 2 * math.pi * t;
      var anomaly = mean;
      for (var i = 0; i < 8; i++) {
        anomaly -=
            (anomaly - eccentricity * math.sin(anomaly) - mean) /
            (1 - eccentricity * math.cos(anomaly));
      }
      final head = place(
        centerAlong - semiMajor * math.cos(anomaly),
        -semiMinor * math.sin(anomaly),
      );
      // The tail points away from the sun, longer the closer it is.
      final away = head - sun;
      final distance = away.distance;
      const nearest = semiMajor * (1 - eccentricity);
      const farthest = semiMajor * (1 + eccentricity);
      final heat = 1 - (distance - nearest) / (farthest - nearest);
      final direction = away / distance;
      const tail = [8.0, 6.5, 5.0, 3.8, 2.8];
      return [
        Dot(sun.dx, sun.dy, 10),
        for (var i = 0; i < tail.length; i++)
          () {
            final position = head + direction * (i * (3 + 3 * heat));
            return Dot(position.dx, position.dy, tail[i]);
          }(),
      ];
    },
  );

  /// A pendulum on a gooey string swinging between two pads, sticking to
  /// each for a moment before it lets go.
  static DotLoader get pendulum => _periodic(
    name: 'Pendulum',
    description:
        'A bob on a gooey string swings between two pads and sticks to '
        'each for a moment before it lets go.',
    steps: 40,
    blend: 12,
    pose: (t) {
      const pivot = Offset(50, 12);
      const length = 50.0;
      const amplitude = 0.55;
      const bobRadius = 10.0;
      final angle = amplitude * math.sin(2 * math.pi * t);
      final direction = Offset(math.sin(angle), math.cos(angle));
      final pad =
          pivot + Offset(math.sin(amplitude), math.cos(amplitude)) * length;
      return [
        Dot(pivot.dx, pivot.dy, 5),
        for (var link = 1; link <= 5; link++)
          () {
            final position = pivot + direction * (length * link / 6);
            return Dot(position.dx, position.dy, 2.6);
          }(),
        () {
          final position = pivot + direction * length;
          return Dot(position.dx, position.dy, bobRadius);
        }(),
        Dot(100 - pad.dx - bobRadius, pad.dy, 5.5),
        Dot(pad.dx + bobRadius, pad.dy, 5.5),
      ];
    },
  );

  /// Every freeform loader, in a pleasant order for a gallery.
  static List<DotLoader> get all => [
    moons,
    mitosis,
    cradle,
    infinity,
    drip,
    bounce,
    juggle,
    lavaLamp,
    comet,
    pendulum,
  ];

  /// The default time between two poses: just under three frames at 60 Hz
  /// and six at 120 Hz, so every pose lasts a whole number of frames.
  static const Duration _step = Duration(milliseconds: 48);

  /// A loader that samples [pose] at [steps] evenly spaced times of one
  /// loop and moves between them in linear [step]s, so the motion keeps
  /// its speed and loops seamlessly.
  ///
  /// [pose] gets a time from 0 (inclusive) to 1 (exclusive).
  static CloudLoader _periodic({
    required String name,
    required String description,
    required int steps,
    required List<Dot> Function(double t) pose,
    required double blend,
    Duration step = _step,
    Size size = const Size.square(100),
  }) => CloudLoader(
    name: name,
    description: description,
    sequence: DotSequence(
      [
        for (var step = 0; step < steps; step++)
          DotKeyframe(DotCloud(pose(step / steps), size: size)),
      ],
      motion: LinearMotion(step),
    ),
    style: DotCloudStyle(blend: blend),
  );
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
