import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/presets/dot_loader.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:motor/motor.dart';

/// Determinate loaders made of freely placed dots.
///
/// Each one turns an amount of progress, from 0 to 1, into a `DotCloud`.
/// Every pose is a smooth function of progress, so small changes glide and
/// larger jumps spring over. Show one with `DotLoaderView`.
abstract final class CloudProgressLoaders {
  /// A ring of beads that swell one by one, clockwise from the top, until
  /// they melt into a solid ring.
  static CloudProgressLoader get halo => const CloudProgressLoader(
    name: 'Halo',
    description:
        'A ring of beads that swell clockwise from the top and melt into a '
        'solid ring.',
    build: _halo,
    style: DotCloudStyle(blend: 10),
    motion: CupertinoMotion(
      duration: Duration(milliseconds: 450),
      bounce: 0.2,
    ),
  );

  /// A gooey bar whose fill reaches out for the beads ahead of it and
  /// swallows them.
  static CloudProgressLoader get beads => const CloudProgressLoader(
    name: 'Beads',
    description:
        'A thin bar whose gooey fill stretches out to swallow the beads '
        'along its track.',
    build: _beads,
    style: DotCloudStyle(blend: 10),
    motion: CupertinoMotion(bounce: 0.15),
  );

  /// A round flask filling with liquid, its surface rippling as it rises.
  static CloudProgressLoader get tide => const CloudProgressLoader(
    name: 'Tide',
    description:
        'A round flask that fills with liquid, its surface rippling as it '
        'rises.',
    build: _tide,
    style: DotCloudStyle(blend: 3),
    motion: CurvedMotion(Duration(milliseconds: 500), Curves.easeOutCubic),
  );

  /// A drop that grows by gathering the droplets orbiting it.
  static CloudProgressLoader get gather => const CloudProgressLoader(
    name: 'Gather',
    description:
        'A drop that grows by pulling in the droplets around it, one after '
        'another.',
    build: _gather,
    style: DotCloudStyle(blend: 10),
    motion: CupertinoMotion(
      duration: Duration(milliseconds: 600),
      bounce: 0.25,
    ),
  );

  /// An arc sweeping clockwise behind a fat head, closing into a ring.
  static CloudProgressLoader get comet => const CloudProgressLoader(
    name: 'Comet',
    description:
        'A fat blob sweeps clockwise, drawing a tapering tail that closes '
        'into a ring.',
    build: _comet,
    style: DotCloudStyle(blend: 6),
    motion: CupertinoMotion(duration: Duration(milliseconds: 450)),
  );

  /// A chomping mouth that eats its way along a row of pellets.
  static CloudProgressLoader get chomp => const CloudProgressLoader(
    name: 'Chomp',
    description: 'A chomping mouth that eats its way along a row of pellets.',
    build: _chomp,
    style: DotCloudStyle(blend: 2.5),
    motion: CurvedMotion(Duration(milliseconds: 400), Curves.easeOutCubic),
  );

  /// A tube that fills with balls dropping in from above.
  static CloudProgressLoader get tube => const CloudProgressLoader(
    name: 'Tube',
    description: 'Balls drop into a tube and stack up from the bottom.',
    build: _tube,
    style: DotCloudStyle(blend: 3.5),
    motion: CupertinoMotion(bounce: 0.3),
  );

  /// A puddle that stretches around a ring, beading into a necklace whose
  /// ends clasp at the top.
  static CloudProgressLoader get clasp => const CloudProgressLoader(
    name: 'Clasp',
    description:
        'A puddle stretches up both sides of a ring, beading into a '
        'necklace that clasps at the top.',
    build: _clasp,
    style: DotCloudStyle(blend: 8),
    motion: CupertinoMotion(
      duration: Duration(milliseconds: 550),
      bounce: 0.2,
    ),
  );

  /// An hourglass whose top bulb drains, drop by drop, into the bottom.
  static CloudProgressLoader get hourglass => const CloudProgressLoader(
    name: 'Hourglass',
    description:
        'The top bulb of an hourglass drains in a stream of drops into a '
        'pile that grows in the bottom bulb.',
    build: _hourglass,
    style: DotCloudStyle(blend: 4),
    motion: CurvedMotion(Duration(milliseconds: 500), Curves.easeInOutCubic),
  );

  /// Every determinate cloud loader.
  static List<DotLoader> get all => [
    halo,
    beads,
    tide,
    gather,
    comet,
    chomp,
    tube,
    clasp,
    hourglass,
  ];
}

const double _tau = 2 * math.pi;

double _clamp01(double value) => value.clamp(0.0, 1.0);

double _lerp(double from, double to, double t) => from + (to - from) * t;

double _smoothstep(double edge0, double edge1, double value) {
  final t = _clamp01((value - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

/// The progress of item [index] of [count] items that each take a [window]
/// of the overall [progress], starting one after another.
double _staggered(double progress, int index, int count, double window) {
  final start = count == 1 ? 0.0 : index * (1 - window) / (count - 1);
  return _clamp01((progress - start) / window);
}

Dot _polar(double angle, double distance, double radius) => Dot(
  50 + math.cos(angle) * distance,
  50 + math.sin(angle) * distance,
  radius,
);

DotCloud _halo(double progress) {
  const count = 12;
  return DotCloud([
    for (var i = 0; i < count; i++)
      _polar(
        -math.pi / 2 + i / count * _tau,
        36,
        _lerp(2.8, 10.5, _smoothstep(0, 1, progress * count - i)),
      ),
  ]);
}

DotCloud _beads(double progress) {
  const count = 14;
  const start = 20.0;
  const length = 160.0;
  const fillRadius = 9.0;
  final head = start + length * progress;
  return DotCloud(
    [
      Dot(head, 20, fillRadius),
      for (var i = 0; i < count; i++)
        () {
          final home = start + length * i / (count - 1);
          // How far the head has passed this bead; negative while ahead.
          final passed = head - home;
          // Beads lean toward the approaching fill before it swallows them.
          final lean =
              _smoothstep(-26, -8, passed) * (1 - _smoothstep(-8, 6, passed));
          return Dot(
            home - 5 * lean,
            20,
            _lerp(3, fillRadius, _smoothstep(-6, 6, passed)) + 0.8 * lean,
          );
        }(),
    ],
    size: const Size(200, 40),
  );
}

DotCloud _tide(double progress) {
  const shell = 44.0;
  const inner = 36.0;
  const pitch = 5.6;
  const dropRadius = 4.2;
  const shellDots = 30;
  final level = _lerp(50 + inner + 4, 50 - inner - 4, progress);
  final waves = math.sin(progress * math.pi) * 2.2;
  final dots = <Dot>[
    for (var i = 0; i < shellDots; i++)
      _polar(i / shellDots * _tau, shell, 1.6),
  ];
  // Liquid on concentric rings, so its edge is round.
  for (var ring = 0; ring * pitch <= inner - dropRadius; ring++) {
    final distance = ring * pitch;
    final count = math.max(1, (_tau * distance / pitch).round());
    for (var i = 0; i < count; i++) {
      final angle = (i + ring * 0.5) / count * _tau;
      final x = 50 + math.cos(angle) * distance;
      final y = 50 + math.sin(angle) * distance;
      final surface = level + waves * math.sin(x * 0.16 + progress * 14);
      // Drops just above the surface settle onto it and shrink away.
      final wet = _smoothstep(-6, 0, y - surface);
      final settled = math.max(y, surface);
      final room = inner + 2 - Offset(x - 50, settled - 50).distance;
      dots.add(Dot(x, settled, dropRadius * wet * _clamp01(room / 2)));
    }
  }
  return DotCloud(dots);
}

DotCloud _gather(double progress) {
  const droplets = 8;
  final core = math.sqrt(_lerp(7 * 7, 30 * 30, progress));
  return DotCloud([
    Dot(50, 50, core),
    for (var i = 0; i < droplets; i++)
      () {
        final falling = _staggered(progress, i, droplets, 0.3);
        final eased = Curves.easeInCubic.transform(falling);
        return _polar(
          -math.pi / 2 + i / droplets * _tau,
          _lerp(42, core * 0.4, eased),
          _lerp(4.5, 2, eased) * (1 - _smoothstep(0.85, 1, falling)),
        );
      }(),
  ]);
}

DotCloud _comet(double progress) {
  const count = 36;
  const ring = 36.0;
  final closing = _smoothstep(0.86, 1, progress);
  final headAngle = -math.pi / 2 + progress * _tau;
  return DotCloud([
    _polar(headAngle, ring, _lerp(9.5, 4, closing)),
    for (var i = 0; i < count; i++)
      () {
        final along = i / count;
        final behind = progress - along;
        final appear = _smoothstep(0, 1.5 / count, behind);
        final taper = _lerp(6, 2.4, _clamp01(behind / 0.55));
        return _polar(
          -math.pi / 2 + along * _tau,
          ring,
          _lerp(taper, 4, closing) * appear,
        );
      }(),
  ]);
}

DotCloud _chomp(double progress) {
  const width = 120.0;
  const pellets = 4;
  const body = 16.0;
  const spacing = 3.3;
  final x = _lerp(18, width - 22, progress);
  final mouth = 0.12 + 0.8 * (1 - math.cos(progress * _tau * 3.5)) / 2;
  final dots = <Dot>[];
  // The body, on concentric rings so its outline is round.
  for (var ring = 0; ring * spacing <= body - 2.8; ring++) {
    final distance = ring * spacing;
    final count = math.max(1, (_tau * distance / spacing).round());
    for (var i = 0; i < count; i++) {
      // Dots inside the mouth are swept aside onto the jaws.
      final angle = (i + 0.5) / count * _tau - math.pi;
      final jaw = angle.sign * math.max(angle.abs(), mouth);
      dots.add(
        Dot(x + math.cos(jaw) * distance, 20 + math.sin(jaw) * distance, 2.8),
      );
    }
  }
  for (var i = 0; i < pellets; i++) {
    final home = _lerp(48, width - 12, i / (pellets - 1));
    final eaten = _smoothstep(home - 15, home - 6, x);
    dots.add(Dot(home, 20, 3.2 * (1 - eaten)));
  }
  return DotCloud(dots, size: const Size(width, 40));
}

DotCloud _tube(double progress) {
  const balls = 6;
  const ballRadius = 7.0;
  const bottom = 90.0;
  const pitch = 14.2;
  return DotCloud(
    [
      // The walls, a U of tiny dots.
      for (var y = 10.0; y <= 84; y += 3.7) ...[
        Dot(9, y, 1.3),
        Dot(31, y, 1.3),
      ],
      for (var i = 1; i < 8; i++)
        Dot(
          20 - math.cos(i / 8 * math.pi) * 11,
          bottom - 6 + math.sin(i / 8 * math.pi) * 11,
          1.3,
        ),
      for (var i = 0; i < balls; i++)
        () {
          final falling = _staggered(progress, i, balls, 0.34);
          final target = bottom - 8 - i * pitch;
          return Dot(
            20,
            _lerp(
              math.max(target - 34, ballRadius),
              target,
              Curves.easeInQuad.transform(falling),
            ),
            ballRadius * _smoothstep(0, 0.35, falling),
          );
        }(),
    ],
    size: const Size(40, 100),
  );
}

DotCloud _clasp(double progress) {
  const count = 14;
  const ring = 36.0;
  final span = _lerp(0.5, _tau * (count - 1) / count, progress);
  final settle = _smoothstep(0, 0.6, progress);
  return DotCloud([
    for (var i = 0; i < count; i++)
      () {
        final isEnd = i == 0 || i == count - 1;
        return _polar(
          math.pi / 2 + (i / (count - 1) - 0.5) * span,
          ring,
          isEnd ? _lerp(4, 6.6, settle) : _lerp(3, 3.6, settle),
        );
      }(),
  ]);
}

DotCloud _hourglass(double progress) {
  const bulb = 23.0;
  const fullRadius = 19.0;
  const neck = 50.0;
  const glassDots = 24;
  const streamDrops = 6;
  final topRadius = fullRadius * math.sqrt(1 - progress);
  final bottomRadius = fullRadius * math.sqrt(progress);
  final pileTop = neck + 2 * bulb - 2 * bottomRadius - 2;
  final flowing =
      _smoothstep(0, 0.04, progress) * (1 - _smoothstep(0.96, 1, progress));
  return DotCloud([
    // The glass: two dotted bulbs, open where they meet.
    for (final center in [neck - bulb, neck + bulb])
      for (var i = 2; i < glassDots - 1; i++)
        () {
          final angle =
              (center < neck ? math.pi / 2 : -math.pi / 2) +
              i / glassDots * _tau;
          return Dot(
            50 + math.cos(angle) * (bulb + 3),
            center + math.sin(angle) * (bulb + 3),
            1.2,
          );
        }(),
    // The sand left on top rests on the neck; the pile sits on the floor.
    Dot(50, neck - 1 - topRadius, topRadius),
    Dot(50, neck + 2 * bulb - 1 - bottomRadius, bottomRadius),
    // Drops falling from the neck onto the pile.
    for (var i = 0; i < streamDrops; i++)
      () {
        final phase = (progress * 5 + i / streamDrops) % 1;
        final fade = math.pow(math.sin(phase * math.pi), 3).toDouble();
        return Dot(
          50,
          _lerp(neck, pileTop, phase),
          2.4 * fade * flowing,
        );
      }(),
  ]);
}
