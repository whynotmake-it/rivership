// The detector writes its states controller only from events, so a widget
// that listens to the controller can sit above the detector. Disabled is
// configuration: the builder reads it, the controller never holds it.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) =>
      CoilTheme(data: CoilThemeData.light, child: navigator!),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 200, height: 100, child: child),
    ),
  ),
);

/// Rebuilds itself whenever [states] changes, with the detector inside.
/// Both [nodes] are focusable; the detector watches [focusNode].
class _Listener extends StatefulWidget {
  const _Listener({
    required this.states,
    required this.enabled,
    required this.nodes,
    required this.focusNode,
  });

  final WidgetStatesController states;
  final bool enabled;
  final List<FocusNode> nodes;
  final FocusNode focusNode;

  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> {
  @override
  void initState() {
    super.initState();
    widget.states.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.states.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final node in widget.nodes)
        Focus(focusNode: node, child: const SizedBox(height: 10)),
      Expanded(
        child: CoilInteractionDetector(
          states: widget.states,
          enabled: widget.enabled,
          focusNode: widget.focusNode,
          onTap: () {},
          child: const SizedBox.expand(),
        ),
      ),
    ],
  );
}

void main() {
  setUp(CoilInputModality.debugReset);

  testWidgets('a listener above its detector rebuilds without errors when '
      'the detector is disabled or gets a new focus node', (tester) async {
    final states = WidgetStatesController();
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(states.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    // The route keeps its first child, so changes come through a notifier.
    final config = ValueNotifier((true, first));
    addTearDown(config.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: config,
          builder: (context, value, _) => _Listener(
            states: states,
            enabled: value.$1,
            nodes: [first, second],
            focusNode: value.$2,
          ),
        ),
      ),
    );
    for (final enabled in [false, true]) {
      config.value = (enabled, first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'enabled: $enabled');
      expect(states.value, isNot(contains(WidgetState.disabled)));
    }

    // From the keyboard, the second node takes focus; then the detector
    // starts watching it.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    second.requestFocus();
    await tester.pump();
    expect(states.value, isNot(contains(WidgetState.focused)));
    config.value = (true, second);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'new focus node');
    expect(states.value, contains(WidgetState.focused));
  });

  testWidgets('a disabled control shows disabled and drops its hover; '
      'enabled again under the same pointer, it hovers', (tester) async {
    Set<WidgetState>? shown;
    final enabledNotifier = ValueNotifier(true);
    addTearDown(enabledNotifier.dispose);
    Future<void> pump({required bool enabled}) async {
      enabledNotifier.value = enabled;
      await tester.pump();
    }

    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: enabledNotifier,
          builder: (context, on, _) => CoilInteraction(
            onPressed: on ? () {} : null,
            builder: (context, states, _) {
              shown = states;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(CoilInteraction)),
    );
    await tester.pump();
    expect(shown, {WidgetState.hovered});

    await pump(enabled: false);
    expect(shown, {WidgetState.disabled});

    await pump(enabled: true);
    expect(shown, {WidgetState.hovered});
  });
}
