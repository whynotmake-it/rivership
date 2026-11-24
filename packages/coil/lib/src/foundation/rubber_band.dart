/// Rubber-band resistance for a value pulled or thrown past its end.
///
/// The result keeps growing with [overshoot] but ever more softly and never
/// reaches [limit]: `limit * (1 - 1 / (1 + overshoot / limit))` for a
/// positive overshoot, mirrored for a negative one. It starts out following
/// the overshoot one to one (slope 1 at 0), so a small overshoot is hardly
/// resisted, and a big one approaches [limit] without a hard stop.
///
/// This is the classic `(1 - 1 / (x * c / d + 1)) * d` with the constant
/// `c` equal to the limit `d`.
///
/// [limit] is the asymptote, in the unit of [overshoot]. It must be
/// positive.
double coilRubberBand(double overshoot, {required double limit}) {
  assert(limit > 0, 'The limit must be positive.');
  final magnitude = limit * (1 - 1 / (1 + overshoot.abs() / limit));
  return overshoot.isNegative ? -magnitude : magnitude;
}
