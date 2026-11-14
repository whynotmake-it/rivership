import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';
import 'src/test_icons.dart';

/// Icon tabs that show only the selected tab's label.
class _Tabs extends StatefulWidget {
  const _Tabs();

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int value = 0;

  @override
  Widget build(BuildContext context) => CoilTabs<int>(
    tabs: [
      for (final (i, label) in ['Overview', 'Analytics', 'Reports'].indexed)
        CoilTab(value: i, label: label, icon: const TestIcon(TestGlyph.home)),
    ],
    value: value,
    onChanged: (v) => setState(() => value = v),
    labels: CoilTabLabels.selected,
  );
}

/// The first tab's width: where the second tab's icon starts.
double _firstWidth(WidgetTester tester) {
  final icons = find.byType(TestIcon);
  return tester.getTopLeft(icons.at(1)).dx - tester.getTopLeft(icons.at(0)).dx;
}

Future<void> _pump(WidgetTester tester) async {
  useScreen(tester, TestScreen.desktop);
  await tester.pumpWidget(
    testApp(
      tier: CoilTier.pointer,
      home: const Center(child: _Tabs()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the tab at [index] (its icon) and pumps one frame of the change.
Future<void> _select(WidgetTester tester, int index) async {
  await tester.tap(find.byType(TestIcon).at(index));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('a closing label narrows its tab while it fades', (
    tester,
  ) async {
    await _pump(tester);
    final open = _firstWidth(tester);
    await _select(tester, 1);
    // "Overview" is still fading out, and the tab is already narrower.
    expect(find.text('Overview'), findsWidgets);
    expect(_firstWidth(tester), lessThan(open));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsNothing);
    expect(_firstWidth(tester), lessThan(open));
  });

  testWidgets('an opening label widens its tab', (tester) async {
    await _pump(tester);
    await _select(tester, 1);
    await tester.pumpAndSettle();
    final closed = _firstWidth(tester);
    await _select(tester, 0);
    final mid = _firstWidth(tester);
    expect(mid, greaterThan(closed));
    await tester.pumpAndSettle();
    expect(_firstWidth(tester), greaterThan(mid));
  });

  testWidgets('with reduced motion the tab fits its label at once', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester);
    final open = _firstWidth(tester);
    await _select(tester, 1);
    final first = _firstWidth(tester);
    expect(first, lessThan(open));
    await tester.pumpAndSettle();
    expect(_firstWidth(tester), first);
  });
}
