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

/// The focus node of the control around [element]: the nearest one that can
/// take focus, past the inert ones a switcher puts around its content.
FocusNode _controlNode(Element element) {
  var node = Focus.of(element);
  while (!node.canRequestFocus && node.parent != null) {
    node = node.parent!;
  }
  return node;
}

void main() {
  testWidgets('a focused tab keeps focus when a tab is inserted before it', (
    tester,
  ) async {
    await tester.pumpWidget(_tabs(['a', 'b', 'c']));
    _controlNode(tester.element(find.text('b').first)).requestFocus();
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
