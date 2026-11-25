import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

Widget _app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  debugShowCheckedModeBanner: false,
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light,
    child: DefaultTextStyle(
      style: const TextStyle(fontSize: 16, height: 1.4),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  ),
);

/// Pumps [initial] and returns a notifier that swaps the markdown.
Future<ValueNotifier<Widget>> _pumpLive(
  WidgetTester tester,
  Widget initial,
) async {
  final content = ValueNotifier(initial);
  addTearDown(content.dispose);
  await tester.pumpWidget(
    _app(
      ValueListenableBuilder(
        valueListenable: content,
        builder: (context, child, _) => child,
      ),
    ),
  );
  return content;
}

/// `$…$` as a `math` element, for the inline-builder test.
class _Dollar extends md.InlineSyntax {
  _Dollar() : super(r'\$([^$]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

void main() {
  group('CoilMarkdownSession', () {
    test('a finished block is parsed once and reused as text grows', () {
      var parses = 0;
      final session = CoilMarkdownSession(
        parse: (s) {
          parses++;
          return coilParseMarkdown(s);
        },
      );
      final first = session.update('# Title\n\nFirst para');
      // The heading is done once the next block has begun.
      expect(first.stable.map((s) => s.source), ['# Title\n\n']);
      final second = session.update('# Title\n\nFirst paragraph.\n\nSecond');
      expect(second.stable.map((s) => s.source), [
        '# Title\n\n',
        'First paragraph.\n\n',
      ]);
      final before = parses;
      final third = session.update(
        '# Title\n\nFirst paragraph.\n\nSecond paragraph grows',
      );
      expect(third.stable, hasLength(2));
      expect(identical(third.stable[0], second.stable[0]), isTrue);
      expect(parses - before, 1, reason: 'only the tail');
      expect(third.pending!.source, 'Second paragraph grows');
    });

    test('the pending segment keeps its id when it becomes stable', () {
      final session = CoilMarkdownSession();
      final a = session.update('One\n\nTw');
      final pendingId = a.pending!.id;
      final b = session.update('One\n\nTwo\n\nThree');
      expect(b.stable.last.id, pendingId);
    });

    test('lists, fences and HTML blocks stay open across blank lines', () {
      int? cut(String s) => markdownBoundary(s, 0);
      // A blank line between items keeps the list (loose) open.
      expect(cut('- a\n\n- b\n'), isNull);
      // An indented paragraph continues the item.
      expect(cut('- a\n\n  more\n'), isNull);
      // A paragraph at column 0 closes it.
      expect(cut('- a\n\nNext\n'), '- a\n\n'.length);
      // Blank lines inside a fence don't count.
      expect(cut('```\na\n\nb\n'), isNull);
      expect(cut('```\na\n\nb\n```\n\nNext\n'), '```\na\n\nb\n```\n\n'.length);
      // Nor inside an HTML comment.
      expect(cut('<!--\na\n\nb\n'), isNull);
      // A growing last line already starts a block when it can't continue
      // the one before; after a list, a possible next item waits.
      expect(cut('Para\n\nNex'), 'Para\n\n'.length);
      expect(cut('- a\n\n-'), isNull);
      expect(cut('Para\n\n  ind'), isNull);
    });

    test('link definitions and edits start over', () {
      final session = CoilMarkdownSession()..update('One\n\nTwo\n\nThree');
      expect(session.update('[a]: http://x\n\nOne\n\nTwo').stable, isEmpty);
      final s2 = CoilMarkdownSession()..update('One\n\nTwo\n\nThree');
      final edited = s2.update('Uno\n\nTwo\n\nThree');
      expect(edited.reset, isTrue);
      expect(edited.stable.first.source, 'Uno\n\n');
    });
  });

  group('completeMarkdown', () {
    test('closes what can pair, innermost first, before trailing spaces', () {
      expect(completeMarkdown('the **key ide'), 'the **key ide**');
      expect(completeMarkdown('**bold *it'), '**bold *it***');
      expect(completeMarkdown('~~old'), '~~old~~');
      expect(completeMarkdown('run `npm i'), 'run `npm i`');
      expect(
        completeMarkdown('see [docs](https://fl'),
        'see [docs](https://fl)',
      );
      expect(completeMarkdown('the **key '), 'the **key** ');
    });

    test('drops a marker with nothing after it yet', () {
      expect(completeMarkdown('the **'), 'the ');
      expect(completeMarkdown('run `'), 'run ');
    });

    test('leaves stars that open nothing, closed syntax, earlier blocks and '
        'open fences', () {
      expect(completeMarkdown('- item'), '- item');
      expect(completeMarkdown('2 * 3'), '2 * 3');
      expect(completeMarkdown('**done** and `x`'), '**done** and `x`');
      expect(completeMarkdown('**open\n\nnext'), '**open\n\nnext');
      expect(completeMarkdown('```\nfoo **'), '```\nfoo **');
      expect(completeMarkdown(r'a \*b'), r'a \*b');
    });
  });

  group('CoilMarkdown', () {
    testWidgets('GitHub-flavored blocks with a heading ramp, headings and '
        'task boxes as screen readers expect', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const CoilMarkdown('''
# Title

Body text.

## Section

| A | B |
|---|--:|
| 1 | 2 |

- [x] done
- [ ] todo

> quoted

---

```dart
x
```
'''),
        ),
      );
      await tester.pumpAndSettle();
      final h1 = tester.getSize(find.text('Title')).height;
      final h2 = tester.getSize(find.text('Section')).height;
      final body = tester.getSize(find.text('Body text.')).height;
      expect(h1, greaterThan(h2));
      expect(h2, greaterThan(body));
      expect(find.text('quoted'), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
      final boxes = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.checked != null,
      );
      expect(boxes, findsNWidgets(2));
      expect(
        tester.getSemantics(find.text('Section')),
        isSemantics(label: 'Section', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('while streaming, a finished block is built once', (
      tester,
    ) async {
      var builds = 0;
      // One map for every update: a new map is new builders, which builds
      // everything again.
      final builders = <String, CoilMarkdownBlockBuilder>{
        'pre': (context, element, state) {
          builds++;
          return null;
        },
      };
      Widget md(String text) =>
          CoilMarkdown(text, streaming: true, blockBuilders: builders);
      final content = await _pumpLive(tester, md('```\ncode\n```\n\nNext'));
      await tester.pump();
      final first = builds;
      for (final more in [' word', ' word word', ' word word word']) {
        content.value = md('```\ncode\n```\n\nNext$more');
        await tester.pump();
      }
      expect(builds, first);
    });

    testWidgets('a block that arrives later grows in, so nothing jumps; a '
        'reply loaded whole shows at once', (tester) async {
      const two = 'First.\n\nSecond.';
      final markdown = find.byType(CoilMarkdown);
      final content = await _pumpLive(
        tester,
        const CoilMarkdown('First.', streaming: true),
      );
      await tester.pumpAndSettle();
      final one = tester.getSize(markdown).height;
      content.value = const CoilMarkdown(two, streaming: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final growing = tester.getSize(markdown).height;
      await tester.pumpAndSettle();
      final full = tester.getSize(markdown).height;
      expect(growing, greaterThan(one));
      expect(growing, lessThan(full));

      // The same text loaded whole is at full height on its first frame.
      content.value = const KeyedSubtree(
        key: ValueKey('history'),
        child: CoilMarkdown(two),
      );
      await tester.pump();
      expect(tester.getSize(markdown).height, full);
    });

    testWidgets('half-written bold shows bold while streaming', (tester) async {
      await tester.pumpWidget(
        _app(const CoilMarkdown('the **key ide', streaming: true)),
      );
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('links call onTapLink', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _app(
          CoilMarkdown(
            '[Docs](https://coil.dev)',
            onTapLink: (href) => tapped = href,
          ),
        ),
      );
      await tester.tapOnText(find.textRange.ofSubstring('Docs'));
      expect(tapped, 'https://coil.dev');
    });

    testWidgets('Copy waits until the code block can no longer change', (
      tester,
    ) async {
      final content = await _pumpLive(
        tester,
        const CoilMarkdown('```\nlet x\n', streaming: true),
      );
      await tester.pump();
      CoilButton copy() => tester.widget(
        find.byWidgetPredicate(
          (w) => w is CoilButton && w.semanticLabel == 'Copy code',
        ),
      );
      expect(copy().onPressed, isNull);
      content.value = const CoilMarkdown('```\nlet x\n```\n\nDone.');
      await tester.pump();
      expect(copy().onPressed, isNotNull);
    });

    testWidgets('extension: an inline syntax and its builder', (tester) async {
      await tester.pumpWidget(
        _app(
          CoilMarkdown(
            r'Area is $a_i b_i$ here',
            inlineSyntaxes: [_Dollar()],
            inlineBuilders: {
              'math': (context, element, style) => TextSpan(
                text: '[math:${element.textContent}]',
              ),
            },
          ),
        ),
      );
      expect(find.textContaining('[math:a_i b_i]'), findsOneWidget);
    });
  });
}
