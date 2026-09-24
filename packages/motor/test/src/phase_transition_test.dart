import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('PhaseTransition', () {
    test('a transition reports its target as phase and origin as lastPhase',
        () {
      const PhaseTransition<String> transition =
          PhaseTransitioning(from: 'a', to: 'b');
      expect(transition.phase, 'b');
      expect(transition.lastPhase, 'a');
    });

    test('a settled phase is both phase and lastPhase', () {
      const PhaseTransition<String> settled = PhaseSettled('a');
      expect(settled.phase, 'a');
      expect(settled.lastPhase, 'a');
    });

    test('compares by value', () {
      // Non-const instances, so equality is not identity.
      final from = ['a'].single;
      expect(
        PhaseTransitioning(from: from, to: 'b'),
        const PhaseTransitioning(from: 'a', to: 'b'),
      );
      expect(
        PhaseTransitioning(from: from, to: 'b').hashCode,
        const PhaseTransitioning(from: 'a', to: 'b').hashCode,
      );
      expect(PhaseSettled(from), const PhaseSettled('a'));
      expect(PhaseSettled(from).hashCode, const PhaseSettled('a').hashCode);

      expect(
        const PhaseTransitioning(from: 'a', to: 'b'),
        isNot(const PhaseTransitioning(from: 'b', to: 'a')),
      );
      expect(const PhaseSettled('b'), isNot(const PhaseSettled('a')));
      expect(
        const PhaseSettled('b'),
        isNot(const PhaseTransitioning(from: 'b', to: 'b')),
      );
    });

    test('describes itself', () {
      expect(
        const PhaseTransitioning(from: 'a', to: 'b').toString(),
        'PhaseTransitioning(from: a, to: b)',
      );
      expect(const PhaseSettled('a').toString(), 'PhaseSettled(a)');
    });
  });
}
