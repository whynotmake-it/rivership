import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:turns/markdown.dart';

void main() {
  group('MarkdownSession', () {
    test('a finished block is parsed once and reused as text grows', () {
      var parses = 0;
      final session = MarkdownSession(
        parse: (s) {
          parses++;
          return parseMarkdown(s);
        },
      );
      final first = session.update('# Title\n\nFirst para');
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
      final session = MarkdownSession();
      final a = session.update('One\n\nTw');
      final pendingId = a.pending!.id;
      final b = session.update('One\n\nTwo\n\nThree');
      expect(b.stable.last.id, pendingId);
    });

    test('lists, fences and HTML blocks stay open across blank lines', () {
      int? cut(String s) => markdownBoundary(s, 0);
      expect(cut('- a\n\n- b\n'), isNull);
      expect(cut('- a\n\n  more\n'), isNull);
      expect(cut('- a\n\nNext\n'), '- a\n\n'.length);
      expect(cut('```\na\n\nb\n'), isNull);
      expect(cut('```\na\n\nb\n```\n\nNext\n'), '```\na\n\nb\n```\n\n'.length);
      expect(cut('<!--\na\n\nb\n'), isNull);
      expect(cut('Para\n\nNex'), 'Para\n\n'.length);
      expect(cut('- a\n\n-'), isNull);
      expect(cut('Para\n\n  ind'), isNull);
    });

    test('link definitions and edits start over', () {
      final session = MarkdownSession()..update('One\n\nTwo\n\nThree');
      expect(session.update('[a]: http://x\n\nOne\n\nTwo').stable, isEmpty);
      final s2 = MarkdownSession()..update('One\n\nTwo\n\nThree');
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

    test(
      'leaves stars that open nothing, closed syntax, earlier blocks and '
      'open fences',
      () {
        expect(completeMarkdown('- item'), '- item');
        expect(completeMarkdown('2 * 3'), '2 * 3');
        expect(completeMarkdown('**done** and `x`'), '**done** and `x`');
        expect(completeMarkdown('**open\n\nnext'), '**open\n\nnext');
        expect(completeMarkdown('```\nfoo **'), '```\nfoo **');
        expect(completeMarkdown(r'a \*b'), r'a \*b');
      },
    );
  });

  group('latexMathSyntaxes', () {
    test('parses inline and display math while leaving currency as text', () {
      final nodes = parseMarkdown(
        r'Costs $5 and $10, bare $5$, inline $a_i b_i$, and display:'
        '\n\n'
        r'$$'
        '\n'
        r'\sum_{i=1}^n x_i'
        '\n'
        r'$$',
        inlineSyntaxes: latexMathSyntaxes,
      );

      final mathElements = <md.Element>[];
      void visit(List<md.Node>? list) {
        if (list == null) return;
        for (final node in list) {
          if (node is md.Element) {
            if (node.tag == 'math') mathElements.add(node);
            visit(node.children);
          }
        }
      }

      visit(nodes);
      expect(mathElements, hasLength(2));
      expect(mathElements[0].textContent, 'a_i b_i');
      expect(mathElements[0].attributes['display'], isNull);
      expect(mathElements[1].textContent, r'\sum_{i=1}^n x_i');
      expect(mathElements[1].attributes['display'], '1');
    });
  });
}
