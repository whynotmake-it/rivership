// A row that pairs text with one toggle is one tap target, like a native
// settings row. Rows with other controls stay inert outside them.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, navigator) => CoilTheme(
    data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
    child: navigator!,
  ),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 480, child: child),
    ),
  ),
);

/// A setting row with a switch whose taps land in [taps].
class _SwitchSetting extends StatefulWidget {
  const _SwitchSetting({required this.taps});

  final List<bool> taps;

  @override
  State<_SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<_SwitchSetting> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => CoilSettingRow(
    label: const Text('Wi-Fi'),
    description: const Text('Join known networks'),
    trailing: CoilSwitch(
      value: _on,
      onChanged: (value) {
        widget.taps.add(value);
        setState(() => _on = value);
      },
    ),
  );
}

/// The field scope the switch reads: what the row tells it.
CoilFieldScope _scopeOfSwitch(WidgetTester tester) => tester.widget(
  find
      .ancestor(
        of: find.byType(CoilSwitch),
        matching: find.byType(CoilFieldScope),
      )
      .first,
);

bool _textFocused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  testWidgets('a tap on the padding, the gap or the description toggles a '
      "setting row's switch", (tester) async {
    final taps = <bool>[];
    await tester.pumpWidget(_app(_SwitchSetting(taps: taps)));
    final row = tester.getRect(find.byType(CoilSettingRow));
    final toggle = tester.getRect(find.byType(CoilSwitch));

    // The padding above the label.
    await tester.tapAt(row.topLeft + const Offset(4, 4));
    await tester.pumpAndSettle();
    // The gap between the text and the switch.
    await tester.tapAt(Offset(toggle.left - 12, toggle.center.dy));
    await tester.pumpAndSettle();
    // The description.
    await tester.tap(find.text('Join known networks'));
    await tester.pumpAndSettle();

    expect(taps, [true, false, true]);
  });

  testWidgets('a setting row is one semantics node: the switch, named by '
      'its label and description', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <bool>[];
    await tester.pumpWidget(_app(_SwitchSetting(taps: taps)));
    expect(
      tester.getSemantics(find.byType(CoilSwitch)),
      isSemantics(
        label: 'Wi-Fi\nJoin known networks',
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a hovering mouse over the row lights the switch; a touch '
      'leaves nothing lit', (tester) async {
    final taps = <bool>[];
    await tester.pumpWidget(_app(_SwitchSetting(taps: taps)));
    final description = tester.getCenter(find.text('Join known networks'));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: description);
    await tester.pump();
    expect(_scopeOfSwitch(tester).containerHovered, isTrue);
    await mouse.moveTo(const Offset(700, 20));
    await tester.pump();
    expect(_scopeOfSwitch(tester).containerHovered, isFalse);

    final finger = await tester.startGesture(description);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_scopeOfSwitch(tester).containerPressed, isTrue);
    await finger.up();
    await tester.pumpAndSettle();
    expect(_scopeOfSwitch(tester).containerPressed, isFalse);
    expect(_scopeOfSwitch(tester).containerHovered, isFalse);
  });

  testWidgets("a gap tap in a slider's row changes nothing", (tester) async {
    final changes = <double>[];
    await tester.pumpWidget(
      _app(
        CoilSettingRow(
          label: const Text('Volume'),
          description: const Text('For alerts'),
          trailing: SizedBox(
            width: 160,
            child: CoilSlider(value: 0.5, onChanged: changes.add),
          ),
        ),
      ),
    );
    final slider = tester.getRect(find.byType(CoilSlider));
    await tester.tapAt(Offset(slider.left - 12, slider.center.dy));
    await tester.tap(find.text('For alerts'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('a row with two switches toggles neither from a gap', (
    tester,
  ) async {
    final taps = <bool>[];
    await tester.pumpWidget(
      _app(
        CoilSettingRow(
          label: const Text('Sync'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoilSwitch(value: false, onChanged: taps.add),
              CoilSwitch(value: false, onChanged: taps.add),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
  });

  testWidgets('a horizontal field toggles its checkbox from the gap', (
    tester,
  ) async {
    final taps = <bool?>[];
    await tester.pumpWidget(
      _app(
        CoilField(
          orientation: CoilFieldOrientation.horizontal,
          label: const Text('Newsletter'),
          description: const Text('Once a month'),
          child: CoilCheckbox(value: false, onChanged: taps.add),
        ),
      ),
    );
    final box = tester.getRect(find.byType(CoilCheckbox));
    await tester.tapAt(Offset(box.left - 24, box.center.dy));
    await tester.tap(find.text('Once a month'));
    await tester.pumpAndSettle();
    expect(taps, [true, true]);
  });

  testWidgets("a horizontal field's gap doesn't focus its text field", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CoilField(
          orientation: CoilFieldOrientation.horizontal,
          label: Text('Name'),
          description: Text('As on your card'),
          child: CoilInput(),
        ),
      ),
    );
    await tester.tap(find.text('As on your card'));
    await tester.pumpAndSettle();
    expect(_textFocused(tester), isFalse);

    // The label still focuses it, as an HTML label does.
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(_textFocused(tester), isTrue);
  });
}
