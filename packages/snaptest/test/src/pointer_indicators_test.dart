import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/src/video/pointer_indicators.dart';

void main() {
  late PointerIndicators indicators;
  setUp(
    () => indicators = PointerIndicators(const Duration(microseconds: 100)),
  );

  test('a quick tap survives until its down-based deadline', () {
    indicators
      ..handle(const PointerDownEvent(pointer: 1, position: Offset(10, 20)), 0)
      ..handle(const PointerUpEvent(pointer: 1), 10);
    expect(indicators.takeChangesThrough(99).last.positions, [
      const Offset(10, 20),
    ]);
    final expired = indicators.takeChangesThrough(100).single;
    expect(expired.timeUs, 100);
    expect(expired.positions, isEmpty);
  });

  test('a long drag has no trailing hold and retains its latest position', () {
    indicators
      ..handle(const PointerDownEvent(pointer: 1), 0)
      ..handle(
        const PointerMoveEvent(pointer: 1, position: Offset(20, 30)),
        50,
      );
    expect(indicators.takeChangesThrough(100).last.positions, [
      const Offset(20, 30),
    ]);
    indicators.handle(const PointerUpEvent(pointer: 1), 200);
    expect(indicators.takeChangesThrough(200).single.positions, isEmpty);
  });

  test('multiple pointers expire independently and timestamps coalesce', () {
    indicators
      ..handle(const PointerDownEvent(pointer: 1, position: Offset(1, 1)), 0)
      ..handle(const PointerUpEvent(pointer: 1), 0)
      ..handle(const PointerDownEvent(pointer: 2, position: Offset(2, 2)), 30)
      ..handle(const PointerUpEvent(pointer: 2), 30);
    final changes = indicators.takeChangesThrough(200);
    expect(changes.map((c) => c.timeUs), [0, 30, 100, 130]);
    expect(changes[2].positions, [const Offset(2, 2)]);
    expect(changes.last.positions, isEmpty);
  });

  test('cancel removes a pointer immediately', () {
    indicators
      ..handle(const PointerDownEvent(pointer: 1), 0)
      ..handle(const PointerCancelEvent(pointer: 1), 20);
    final cancelled = indicators.takeChangesThrough(200).last;
    expect(cancelled.timeUs, 20);
    expect(cancelled.positions, isEmpty);
  });

  test('a reused pointer ID replaces the released indicator', () {
    indicators
      ..handle(const PointerDownEvent(pointer: 1), 0)
      ..handle(const PointerUpEvent(pointer: 1), 0)
      ..handle(const PointerDownEvent(pointer: 1, position: Offset(5, 5)), 50)
      ..handle(const PointerUpEvent(pointer: 1), 50);
    expect(indicators.takeChangesThrough(100).last.positions, [
      const Offset(5, 5),
    ]);
    expect(indicators.takeChangesThrough(150).single.timeUs, 150);
  });
}
