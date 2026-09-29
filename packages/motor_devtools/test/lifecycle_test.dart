import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:motor/inspection.dart';
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

  for (final visible in [false, true]) {
    testWidgets(
      'idle controllers cost nothing per frame (visible: $visible)',
      (tester) async {
        final idle = <_Counting>[];
        await tester.pumpWidget(
          MotorDevTools(
            visible: visible,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  for (var i = 0; i < 20; i++)
                    _CountingOwner(onCreated: idle.add),
                  _Owner(onCreated: (_) {}),
                ],
              ),
            ),
          ),
        );
        // The first frames refresh the tools once; after that, frames should
        // not touch idle controllers.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        for (final controller in idle) {
          controller.reads = 0;
        }
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(idle.map((c) => c.reads).reduce((a, b) => a + b), 0);
      },
    );
  }
}

/// Counts how often the tools read it.
class _Counting extends TrackController {
  _Counting({required super.vsync});

  int reads = 0;

  @override
  bool get isAnimating {
    reads++;
    return super.isAnimating;
  }

  @override
  // ignore: invalid_use_of_internal_member, counting the tools' reads.
  PlaybackSnapshot internalInspectPlayback() {
    reads++;
    // ignore: invalid_use_of_internal_member, counting the tools' reads.
    return super.internalInspectPlayback();
  }
}

class _CountingOwner extends StatefulWidget {
  const _CountingOwner({required this.onCreated});

  final ValueChanged<_Counting> onCreated;

  @override
  State<_CountingOwner> createState() => _CountingOwnerState();
}

class _CountingOwnerState extends State<_CountingOwner>
    with TickerProviderStateMixin {
  late final controller = _Counting(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onCreated(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
