import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tabs(List<String> values) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light,
    child: Center(
      child: CoilTabs<String>(
        tabs: [for (final v in values) CoilTab(value: v, label: Text(v))],
        value: 'b',
        onChanged: (_) {},
      ),
    ),
  ),
);

/// The label of the tab with primary focus.
String? _focusedLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  String? label;
  void visit(Element e) {
    if (label != null) return;
    final widget = e.widget;
    if (widget is Text) {
      label = widget.data;
      return;
    }
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return label;
}

void main() {
  testWidgets('a focused tab keeps focus when a tab is inserted before it', (
    tester,
  ) async {
    await tester.pumpWidget(_tabs(['a', 'b', 'c']));
    Focus.of(tester.element(find.text('b').first)).requestFocus();
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'b');

    await tester.pumpWidget(_tabs(['new', 'a', 'b', 'c']));
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'b');

    await tester.pumpWidget(_tabs(['c', 'b', 'a']));
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'b');
  });
}
