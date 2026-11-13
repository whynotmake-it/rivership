import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/coil_pattern.dart';
import 'src/select_harness.dart' show fruits;

/// A host that applies every component's `onChanged`, with a trailing
/// button so Tab can leave a group.
class _Host extends StatefulWidget {
  const _Host(this.build, {this.textDirection = TextDirection.ltr});

  final Widget Function(_HostState state) build;
  final TextDirection textDirection;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool checked = false;
  bool on = false;
  int tab = 0;
  int plan = 1;
  Set<int> picked = {0};
  String? fruit = 'banana';

  void update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => Directionality(
      textDirection: widget.textDirection,
      child: CoilTheme(
        data: CoilThemeData.light.copyWith(tier: CoilTier.pointer),
        child: navigator!,
      ),
    ),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(
              key: const ValueKey('target'),
              child: widget.build(this),
            ),
            const SizedBox(height: 16),
            CoilButton(onPressed: () {}, child: const Text('After')),
          ],
        ),
      ),
    ),
  );
}

final _target = find.byKey(const ValueKey('target'));

void main() {
  for (final direction in TextDirection.values) {
    group(direction.name, () {
      Future<void> check(
        WidgetTester tester,
        Widget Function(_HostState) build,
        CoilPattern pattern,
      ) async {
        await tester.pumpWidget(_Host(build, textDirection: direction));
        await expectCoilPattern(tester, _target, pattern);
      }

      testWidgets('CoilButton is a button', (tester) async {
        await check(
          tester,
          (_) => CoilButton(onPressed: () {}, child: const Text('Save')),
          CoilPattern.button,
        );
      });

      testWidgets('CoilCheckbox is a checkbox', (tester) async {
        await check(
          tester,
          (s) => CoilCheckbox(
            value: s.checked,
            semanticLabel: 'Accept',
            onChanged: (v) => s.update(() => s.checked = v!),
          ),
          CoilPattern.checkbox,
        );
      });

      testWidgets('CoilSwitch is a switch', (tester) async {
        await check(
          tester,
          (s) => CoilSwitch(
            value: s.on,
            label: const Text('Wi-Fi'),
            onChanged: (v) => s.update(() => s.on = v),
          ),
          CoilPattern.switchControl,
        );
      });

      testWidgets('CoilTabs is a tab list', (tester) async {
        await check(
          tester,
          (s) => CoilTabs(
            tabs: const [
              CoilTab(value: 0, label: 'Overview'),
              CoilTab(value: 1, label: 'Analytics'),
              CoilTab(value: 2, label: 'Reports'),
            ],
            value: s.tab,
            onChanged: (v) => s.update(() => s.tab = v),
          ),
          CoilPattern.tabs,
        );
      });

      testWidgets('CoilRadioGroup is a radio group', (tester) async {
        await check(
          tester,
          (s) => CoilRadioGroup<int>(
            semanticLabel: 'Plan',
            value: s.plan,
            onChanged: (v) => s.update(() => s.plan = v),
            options: const [
              CoilOption(value: 0, label: 'Free'),
              CoilOption(value: 1, label: 'Team'),
              CoilOption(value: 2, label: 'Enterprise'),
            ],
          ),
          CoilPattern.radioGroup,
        );
      });

      testWidgets('CoilCheckboxGroup is a checkbox group', (tester) async {
        await check(
          tester,
          (s) => CoilCheckboxGroup<int>(
            semanticLabel: 'Notify me',
            values: s.picked,
            onChanged: (v) => s.update(() => s.picked = v),
            options: const [
              CoilOption(value: 0, label: 'Email'),
              CoilOption(value: 1, label: 'Push'),
              CoilOption(value: 2, label: 'SMS'),
            ],
          ),
          CoilPattern.checkboxGroup,
        );
      });

      testWidgets('CoilToggleGroup is a toggle group', (tester) async {
        await check(
          tester,
          (s) => CoilToggleGroup<int>(
            values: s.picked,
            onChanged: (v) => s.update(() => s.picked = v),
            options: const [
              CoilOption(value: 0, label: 'Bold'),
              CoilOption(value: 1, label: 'Italic'),
              CoilOption(value: 2, label: 'Underline'),
            ],
          ),
          CoilPattern.toggleGroup,
        );
      });

      testWidgets('CoilInput is a text field', (tester) async {
        await check(
          tester,
          (_) => const SizedBox(
            width: 240,
            child: CoilInput(placeholder: Text('Email')),
          ),
          CoilPattern.textField,
        );
      });

      testWidgets('CoilSelect is a select', (tester) async {
        await check(
          tester,
          (s) => CoilSelect<String>(
            options: fruits,
            value: s.fruit,
            onChanged: (v) => s.update(() => s.fruit = v),
          ),
          CoilPattern.select,
        );
      });
    });
  }
}
