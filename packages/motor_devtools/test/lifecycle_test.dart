import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

final _track = Track<double>(MotionConverter.single, initial: 0);

/// Owns a controller that plays for ten seconds, reporting it on creation.
class _Owner extends StatefulWidget {
  const _Owner({required this.onCreated, this.label = 'Owned', super.key});

  final ValueChanged<TrackController> onCreated;
  final String? label;

  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> with TickerProviderStateMixin {
  late final controller = TrackController(
    vsync: this,
    debugLabel: widget.label,
  );

  @override
  void initState() {
    super.initState();
    widget.onCreated(controller);
    unawaited(
      controller.animate([
        _track.to(1, motion: const Motion.linear(Duration(seconds: 10))),
      ]),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<bool> _collected(
  WidgetTester tester,
  WeakReference<TrackController> reference,
) async {
  await tester.runAsync(() => forceGC(fullGcCycles: 3));
  return reference.target == null;
}

var _mounts = 0;

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    _mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> _pump(WidgetTester tester, Widget child, {bool enabled = true}) =>
    tester.pumpWidget(
      MotorDevTools(
        enabled: enabled,
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      ),
    );

void main() {
  testWidgets('toggling enabled keeps the app subtree', (tester) async {
    _mounts = 0;
    await _pump(tester, const _Counter());
    await _pump(tester, const _Counter(), enabled: false);
    await _pump(tester, const _Counter());
    expect(_mounts, 1);
  });

  for (final label in ['Owned', null]) {
    testWidgets('does not keep a disposed controller ($label)', (
      tester,
    ) async {
      late WeakReference<TrackController> reference;
      await _pump(
        tester,
        _Owner(label: label, onCreated: (c) => reference = WeakReference(c)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _pump(tester, const SizedBox());
      await tester.pump();
      expect(await _collected(tester, reference), isTrue);
    });
  }

  testWidgets('does not keep controllers once disabled', (tester) async {
    late WeakReference<TrackController> reference;
    final owner = _Owner(
      key: GlobalKey(),
      onCreated: (c) => reference = WeakReference(c),
    );
    await _pump(tester, owner);
    await tester.pump(const Duration(milliseconds: 100));
    await _pump(tester, owner, enabled: false);
    await _pump(tester, const SizedBox(), enabled: false);
    await tester.pump();
    expect(await _collected(tester, reference), isTrue);
  });
}
