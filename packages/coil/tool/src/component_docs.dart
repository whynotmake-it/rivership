import 'package:coil_cli/coil_cli.dart';

/// The generated docs, keyed by path relative to the package root:
/// `doc/llms.txt` and one `doc/components/<name>.md` per component, built
/// from the component sections of [design] (DESIGN.md §14).
///
/// `tool/generate_docs.dart` writes them; a test keeps them fresh.
Map<String, String> generatedDocs(CoilSource coil, String design) {
  final sections = _sections(design);
  final docs = <String, String>{};
  final index = StringBuffer(_llmsHeader);
  for (final component in coil.components.values) {
    final names = coil.exportedNames(component).toList()..sort();
    final mine = [
      for (final s in sections)
        if (_belongsTo(s, component, names)) s,
    ];
    if (mine.isEmpty) {
      throw EjectException(
        'DESIGN.md §14 has no section for ${component.name}.',
      );
    }
    final title = mine.first.title.replaceFirst(RegExp(r'\s*\(.*\)$'), '');
    final page = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln(
        '<!-- Generated from DESIGN.md by `dart run '
        'tool/generate_docs.dart`. Edit DESIGN.md instead. -->',
      )
      ..writeln()
      ..writeln('```dart');
    for (final library in component.libraries) {
      page.writeln("import 'package:coil/$library';");
    }
    page
      ..writeln('```')
      ..writeln()
      ..writeln('Exports ${names.map((n) => '`$n`').join(', ')}.')
      ..writeln()
      ..writeln(
        'To change its look or composition, eject a copy into your app '
        'with `dart run coil_cli:eject ${component.name}` (see '
        '[SKILL.md](../../SKILL.md)). The full spec, including the tokens '
        'and rules these sections cite, is in '
        '[DESIGN.md](../../DESIGN.md).',
      );
    for (final section in mine) {
      page
        ..writeln()
        ..writeln('## ${section.title}')
        ..writeln()
        ..writeln(section.body);
    }
    docs['doc/components/${component.name}.md'] = page.toString();
    index.writeln(
      '- [$title](components/${component.name}.md): '
      '${names.take(4).join(', ')}${names.length > 4 ? ', …' : ''}',
    );
  }
  docs['doc/llms.txt'] = index.toString();
  return docs;
}

const _llmsHeader = '''
# coil

> A Flutter design system on Motor springs, inspired by Fluid
> Functionalism. Works under any WidgetsApp. Import
> `package:coil/coil.dart`, or eject a component to edit its look.

These docs match the installed coil version.

## Start here

- [SKILL.md](../SKILL.md): how to use, theme, eject and update coil
- [README.md](../README.md): layers, interaction rules, tests
- [DESIGN.md](../DESIGN.md): the full spec (tokens, motion, interaction)
- [api_guide.md](api_guide.md): naming and API conventions

## Components

''';

class _Section {
  _Section(this.title, this.body);

  final String title;
  final String body;

  /// The first name in the heading (`Select` in `Select / MultiSelect`).
  String get key => RegExp(r'^\w+').firstMatch(title)!.group(0)!;
}

List<_Section> _sections(String design) {
  final start = design.indexOf(RegExp(r'^## 14\.', multiLine: true));
  final end = design.indexOf(RegExp(r'^## 15\.', multiLine: true));
  final components = design.substring(start, end);
  return [
    for (final m in RegExp(
      r'^#### (.+)\n([\s\S]*?)(?=^#{2,4} |(?![\s\S]))',
      multiLine: true,
    ).allMatches(components))
      _Section(
        m.group(1)!.replaceAll(RegExp(r'\s*\((built|reduced v1)\)'), ''),
        m.group(2)!.trim(),
      ),
  ];
}

/// Whether [section] documents [component]: it is named after one of the
/// component's exports or its folder, or its first line names an export
/// (`CoilInput.multiline` for Textarea).
bool _belongsTo(
  _Section section,
  CoilComponent component,
  List<String> names,
) {
  final snake = section.key
      .replaceAllMapped(RegExp('(?<=[a-z])[A-Z]'), (m) => '_${m[0]}')
      .toLowerCase();
  final firstCode = RegExp(
    r'`(Coil\w+)',
  ).firstMatch(section.body.split('\n').first)?.group(1);
  return names.contains('Coil${section.key}') ||
      snake == component.name ||
      names.contains(firstCode);
}
