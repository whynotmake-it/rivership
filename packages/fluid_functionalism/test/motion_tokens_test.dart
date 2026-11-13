import 'dart:math' as math;

import 'package:fluid_functionalism/fluid_functionalism.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// A Dart port of motion.dev's `findSpring`
/// (`motion-dom/src/animation/generators/spring/find.ts`): Newton's method,
/// 12 iterations from 5/duration, for the undamped frequency at which the
/// spring's envelope has decayed to `safeMin` (0.1%) at `duration`.
({double stiffness, double damping}) findSpring({
  required double duration,
  required double bounce,
  double velocity = 0,
  double mass = 1,
}) {
  const safeMin = 0.001;
  final dampingRatio = (1 - bounce).clamp(0.05, 1.0);
  final d = duration.clamp(0.01, 10.0);

  double angular(double undamped, double ratio) =>
      undamped * math.sqrt(1 - ratio * ratio);

  late double Function(double) envelope;
  late double Function(double) derivative;
  if (dampingRatio < 1) {
    envelope = (undamped) {
      final exponentialDecay = undamped * dampingRatio;
      final delta = exponentialDecay * d;
      final a = exponentialDecay - velocity;
      final b = angular(undamped, dampingRatio);
      final c = math.exp(-delta);
      return safeMin - (a / b) * c;
    };
    derivative = (undamped) {
      final exponentialDecay = undamped * dampingRatio;
      final delta = exponentialDecay * d;
      final dd = delta * velocity + velocity;
      final e = dampingRatio * dampingRatio * undamped * undamped * d;
      final f = math.exp(-delta);
      // motion.dev passes the squared frequency here; kept for fidelity.
      final g = angular(undamped * undamped, dampingRatio);
      final factor = -envelope(undamped) + safeMin > 0 ? -1 : 1;
      return (factor * ((dd - e) * f)) / g;
    };
  } else {
    envelope = (undamped) {
      final a = math.exp(-undamped * d);
      final b = (undamped - velocity) * d + 1;
      return -safeMin + a * b;
    };
    derivative = (undamped) {
      final a = math.exp(-undamped * d);
      final b = (velocity - undamped) * (d * d);
      return a * b;
    };
  }

  var undamped = 5 / d;
  for (var i = 1; i < 12; i++) {
    undamped = undamped - envelope(undamped) / derivative(undamped);
  }
  final stiffness = undamped * undamped * mass;
  return (
    stiffness: stiffness,
    damping: dampingRatio * 2 * math.sqrt(mass * stiffness),
  );
}

void main() {
  const tokens = FluidMotionThemeData();
  final tiers = <String, (Motion, double, double)>{
    // web spring: {duration, bounce}
    'fast': (tokens.fast, 0.08, 0),
    'moderate': (tokens.moderate, 0.16, 0),
    'slow': (tokens.slow, 0.24, 0.12),
  };

  for (final MapEntry(key: name, value: (motion, duration, bounce))
      in tiers.entries) {
    test('$name matches motion.dev spring {$duration s, bounce $bounce}', () {
      final web = findSpring(duration: duration, bounce: bounce);
      final ours = (motion as SpringMotion).description;
      expect(ours.mass, 1);
      expect(ours.stiffness, moreOrLessEquals(web.stiffness, epsilon: 0.5));
      expect(ours.damping, moreOrLessEquals(web.damping, epsilon: 0.01));

      // Sample both springs 0 -> 1 every 5 ms up to the web duration.
      final webSim = SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: web.stiffness,
          damping: web.damping,
        ),
        0,
        1,
        0,
      );
      final ourSim = SpringSimulation(ours, 0, 1, 0);
      for (var ms = 0; ms <= duration * 1000; ms += 5) {
        final t = ms / 1000;
        expect(
          ourSim.x(t),
          moreOrLessEquals(webSim.x(t), epsilon: 1e-4),
          reason: '$name at $ms ms',
        );
      }
      // motion.dev hard-stops at `duration`, when the decay *envelope* is
      // 0.1%; the underdamped curve itself is within a hair of that.
      expect((1 - ourSim.x(duration)).abs(), lessThan(0.0015));
    });
  }

  test('exit and fade tweens are easeInOut, as motion.dev defaults them', () {
    expect(
      tokens.fastExit,
      const CurvedMotion(Duration(milliseconds: 60), Curves.easeInOut),
    );
    expect(
      tokens.moderateExit,
      const CurvedMotion(Duration(milliseconds: 120), Curves.easeInOut),
    );
    expect(
      tokens.slowExit,
      const CurvedMotion(Duration(milliseconds: 160), Curves.easeInOut),
    );
    expect(
      tokens.fade,
      const CurvedMotion(Duration(milliseconds: 80), Curves.easeInOut),
    );
  });
}
