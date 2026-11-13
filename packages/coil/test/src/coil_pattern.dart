// TODO(coil-eject): expose expectCoilPattern outside coil's own tests
// (e.g. as a coil_test package) so ejected components can use it. Until
// then it stays internal: not exported, no extra package.
import 'dart:ui' show CheckedState, SemanticsRole, Tristate;

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The interaction patterns coil components implement. Each one is a
/// contract for semantics, keyboard and focus that [expectCoilPattern]
/// checks in one line.
enum CoilPattern {
  /// A push button: a focusable button node with a tap action; Enter and
  /// Space activate it.
  button,

  /// A checkbox: a checked state that Space flips.
  checkbox,

  /// A switch: a toggled state that Space flips.
  switchControl,

  /// A tab list: one tab stop, arrows move between tabs, Enter selects.
  tabs,

  /// A radio group: one tab stop (the selected radio), arrows move focus
  /// and select with wrapping.
  radioGroup,

  /// A single-line text field.
  textField,

  /// A button that opens a list: expanded state, Enter or Down opens, Escape
  /// closes and returns focus.
  select,
}

/// Checks that the widget at [finder] implements [pattern]:
///
/// * it is reached with Tab;
/// * keyboard focus shows a focus ring (`WidgetState.focused` on its
///   interaction detector), and a pointer press hides it (except on text
///   fields, which show focus while editing however they got it);
/// * its semantics and keys follow [pattern].
///
/// Stateful patterns (checkbox, switch, tabs) need a host that applies
/// `onChanged`. [CoilPattern.tabs] needs something focusable after the tabs
/// so Tab can leave them. Works on ejected copies: it only reads semantics,
/// focus and `CoilInteractionDetector` states.
Future<void> expectCoilPattern(
  WidgetTester tester,
  Finder finder,
  CoilPattern pattern,
) async {
  final semantics = tester.ensureSemantics();
  try {
    expect(finder, findsOneWidget, reason: 'the pattern target');
    await _focusWithTab(tester, finder, pattern);
    expect(
      _focusVisible(tester, finder),
      isTrue,
      reason: '$pattern: keyboard focus shows the focus ring',
    );
    switch (pattern) {
      case CoilPattern.button:
        await _button(tester, finder);
      case CoilPattern.checkbox:
        await _flips(
          tester,
          finder,
          (f) => f.isChecked != CheckedState.none,
          (f) => f.isChecked == CheckedState.isTrue,
          'checked',
        );
      case CoilPattern.switchControl:
        await _flips(
          tester,
          finder,
          (f) => f.isToggled != Tristate.none,
          (f) => f.isToggled == Tristate.isTrue,
          'toggled',
        );
      case CoilPattern.tabs:
        await _tabs(tester, finder);
      case CoilPattern.radioGroup:
        await _radioGroup(tester, finder);
      case CoilPattern.textField:
        await _textField(tester, finder);
      case CoilPattern.select:
        await _select(tester, finder);
    }
    // A text field keeps its focus border while editing, however it was
    // focused (as `:focus-visible` does for inputs); a select opens.
    if (pattern != CoilPattern.select && pattern != CoilPattern.textField) {
      await _pointerHidesRing(tester, finder, pattern);
    }
  } finally {
    semantics.dispose();
  }
}

bool _focusInside(Finder finder) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  final targets = finder.evaluate().toSet();
  var inside = targets.contains(context);
  if (!inside) {
    context.visitAncestorElements((element) {
      inside = targets.contains(element);
      return !inside;
    });
  }
  return inside;
}

Future<void> _focusWithTab(
  WidgetTester tester,
  Finder finder,
  CoilPattern pattern,
) async {
  for (var i = 0; i < 30 && !_focusInside(finder); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(_focusInside(finder), isTrue, reason: '$pattern is reached with Tab');
  await tester.pumpAndSettle();
}

Iterable<CoilInteractionDetector> _detectors(
  WidgetTester tester,
  Finder finder,
) => tester.widgetList<CoilInteractionDetector>(
  find.descendant(of: finder, matching: find.byType(CoilInteractionDetector)),
);

bool _focusVisible(WidgetTester tester, Finder finder) => _detectors(
  tester,
  finder,
).any((d) => d.states.value.contains(WidgetState.focused));

/// Every semantics node at or below [finder]'s nearest node.
List<SemanticsData> _nodes(WidgetTester tester, Finder finder) {
  final root = tester.getSemantics(finder);
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    out.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return out;
}

Future<void> _pointerHidesRing(
  WidgetTester tester,
  Finder finder,
  CoilPattern pattern,
) async {
  final focused = FocusManager.instance.primaryFocus!.context!;
  final box = focused.findRenderObject()! as RenderBox;
  final center = box.localToGlobal(box.size.center(Offset.zero));
  final gesture = await tester.startGesture(
    center,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  expect(
    _focusVisible(tester, finder),
    isFalse,
    reason: '$pattern: a pointer press hides the focus ring',
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _button(WidgetTester tester, Finder finder) async {
  final nodes = _nodes(tester, finder);
  expect(
    nodes.any(
      (n) => n.flagsCollection.isButton && n.hasAction(SemanticsAction.tap),
    ),
    isTrue,
    reason: 'button: a button node with a tap action',
  );
  final context = FocusManager.instance.primaryFocus!.context!;
  final action = Actions.maybeFind<ActivateIntent>(context);
  expect(
    action != null && action.isEnabled(const ActivateIntent()),
    isTrue,
    reason: 'button: Enter and Space activate it',
  );
}

Future<void> _flips(
  WidgetTester tester,
  Finder finder,
  bool Function(SemanticsFlags) has,
  bool Function(SemanticsFlags) value,
  String name,
) async {
  SemanticsData node() => _nodes(tester, finder).firstWhere(
    (n) => has(n.flagsCollection),
    orElse: () => throw TestFailure('$name: no node with a $name state'),
  );
  final before = value(node().flagsCollection);
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pumpAndSettle();
  expect(
    value(node().flagsCollection),
    !before,
    reason: '$name: Space flips the state (needs a stateful host)',
  );
}

Future<void> _tabs(WidgetTester tester, Finder finder) async {
  List<SemanticsData> tabs() =>
      _nodes(tester, finder).where((n) => n.role == SemanticsRole.tab).toList();
  expect(
    _nodes(tester, finder).any((n) => n.role == SemanticsRole.tabBar),
    isTrue,
    reason: 'tabs: a tab bar node',
  );
  expect(tabs().length, greaterThan(1), reason: 'tabs: tab nodes');
  expect(
    tabs().where((n) => n.flagsCollection.isSelected == Tristate.isTrue),
    hasLength(1),
    reason: 'tabs: exactly one selected tab',
  );
  final start = FocusManager.instance.primaryFocus;
  final rtl = Directionality.of(start!.context!) == TextDirection.rtl;
  await tester.sendKeyEvent(
    rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
  );
  await tester.pumpAndSettle();
  final moved = FocusManager.instance.primaryFocus;
  expect(moved, isNot(start), reason: 'tabs: the forward arrow moves focus');
  expect(_focusInside(finder), isTrue);
  final selectedBefore = tabs().indexWhere(
    (n) => n.flagsCollection.isSelected == Tristate.isTrue,
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  final selectedAfter = tabs().indexWhere(
    (n) => n.flagsCollection.isSelected == Tristate.isTrue,
  );
  expect(
    selectedAfter,
    isNot(selectedBefore),
    reason: 'tabs: Enter selects the focused tab (needs a stateful host)',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  expect(
    _focusInside(finder),
    isFalse,
    reason: 'tabs: the tab list is one tab stop',
  );
  // Back in for the pointer check.
  await tester.sendKeyEvent(
    LogicalKeyboardKey.tab,
  );
  await _focusWithTab(tester, finder, CoilPattern.tabs);
}

Future<void> _radioGroup(WidgetTester tester, Finder finder) async {
  List<SemanticsData> radios() => _nodes(
    tester,
    finder,
  ).where((n) => n.flagsCollection.isInMutuallyExclusiveGroup).toList();
  int checked() => radios().indexWhere(
    (n) => n.flagsCollection.isChecked == CheckedState.isTrue,
  );
  expect(
    _nodes(tester, finder).any((n) => n.role == SemanticsRole.radioGroup),
    isTrue,
    reason: 'radioGroup: a radio group node',
  );
  final count = radios().length;
  expect(count, greaterThan(2), reason: 'radioGroup: radio nodes');
  final start = checked();
  expect(start, isNonNegative, reason: 'radioGroup: one radio is checked');
  expect(
    radios().where(
      (n) => n.flagsCollection.isChecked == CheckedState.isTrue,
    ),
    hasLength(1),
    reason: 'radioGroup: exactly one checked radio',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  expect(
    checked(),
    (start + 1) % count,
    reason: 'radioGroup: Down moves focus and selects the next radio',
  );
  expect(_focusInside(finder), isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.pumpAndSettle();
  expect(checked(), start, reason: 'radioGroup: Up selects the previous');
  await tester.sendKeyEvent(LogicalKeyboardKey.end);
  await tester.pumpAndSettle();
  expect(checked(), count - 1, reason: 'radioGroup: End selects the last');
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  expect(checked(), 0, reason: 'radioGroup: Down wraps to the first');
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  expect(
    _focusInside(finder),
    isFalse,
    reason: 'radioGroup: the group is one tab stop',
  );
  await _focusWithTab(tester, finder, CoilPattern.radioGroup);
}

Future<void> _textField(WidgetTester tester, Finder finder) async {
  expect(
    _nodes(tester, finder).any((n) => n.flagsCollection.isTextField),
    isTrue,
    reason: 'textField: a text field node',
  );
  expect(
    tester.testTextInput.hasAnyClients,
    isTrue,
    reason: 'textField: keyboard focus connects the text input',
  );
}

Future<void> _select(WidgetTester tester, Finder finder) async {
  Tristate expanded() => _nodes(tester, finder)
      .firstWhere(
        (n) => n.flagsCollection.isButton,
        orElse: () => throw TestFailure('select: no button node'),
      )
      .flagsCollection
      .isExpanded;
  expect(expanded(), Tristate.isFalse, reason: 'select: collapsed at rest');
  expect(
    _nodes(tester, finder).any(
      (n) =>
          n.flagsCollection.isButton &&
          n.flagsCollection.isEnabled == Tristate.isTrue &&
          n.hasAction(SemanticsAction.tap),
    ),
    isTrue,
    reason: 'select: an enabled button node with a tap action',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  // While open, a modal barrier hides the trigger's node; the list is a
  // menu node with the focus.
  final menu = find.semantics
      .byPredicate((node) => node.getSemanticsData().role == SemanticsRole.menu)
      .evaluate()
      .isNotEmpty;
  expect(menu, isTrue, reason: 'select: Down opens a menu list');
  expect(_focusInside(finder), isFalse, reason: 'select: the list has focus');
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(expanded(), Tristate.isFalse, reason: 'select: Escape closes it');
  expect(
    _focusInside(finder),
    isTrue,
    reason: 'select: focus returns to the trigger',
  );
  expect(
    _focusVisible(tester, finder),
    isTrue,
    reason: 'select: the returned focus shows its ring after keyboard use',
  );
}
