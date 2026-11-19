import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  test(
      'a transition reports its target as phase and the phase it leaves as '
      'lastPhase, a settled phase is both', () {
    const PhaseTransition<String> transition =
        PhaseTransitioning(from: 'a', to: 'b');
    expect(transition.phase, 'b');
    expect(transition.lastPhase, 'a');

    const PhaseTransition<String> settled = PhaseSettled('a');
    expect(settled.phase, 'a');
    expect(settled.lastPhase, 'a');
  });
}
