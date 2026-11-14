import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// [source] parsed without resolving anything.
CompilationUnit parse(String source) =>
    parseString(content: source, throwIfDiagnostics: false).unit;

/// The URI of every `import`, `export` and `part` in [unit], with its
/// directive.
Iterable<(UriBasedDirective, String)> directiveUris(CompilationUnit unit) => [
  for (final directive in unit.directives)
    if (directive is UriBasedDirective)
      if (directive.uri.stringValue case final uri?) (directive, uri),
];

/// The names a `show` lists, or null without one.
Set<String>? shownNames(NamespaceDirective directive) {
  final shows = directive.combinators.whereType<ShowCombinator>();
  if (shows.isEmpty) return null;
  return {
    for (final show in shows)
      for (final name in show.shownNames) name.name,
  };
}

/// The names a `hide` lists.
Set<String> hiddenNames(NamespaceDirective directive) => {
  for (final hide in directive.combinators.whereType<HideCombinator>())
    for (final name in hide.hiddenNames) name.name,
};

/// The public top-level names [unit] declares.
Set<String> declaredNames(CompilationUnit unit) => {
  for (final member in unit.declarations)
    for (final name in _names(member))
      if (!name.startsWith('_')) name,
};

Iterable<String> _names(CompilationUnitMember member) => switch (member) {
  TopLevelVariableDeclaration(:final variables) => [
    for (final v in variables.variables) v.name.lexeme,
  ],
  ClassDeclaration(:final namePart) ||
  EnumDeclaration(:final namePart) ||
  ExtensionTypeDeclaration(:final namePart) => [namePart.typeName.lexeme],
  MixinDeclaration(:final name) ||
  FunctionDeclaration(:final name) ||
  TypeAlias(:final name) => [name.lexeme],
  ExtensionDeclaration(:final name) => [?name?.lexeme],
  _ => const [],
};

/// [source] with its imports and exports in the order `directives_ordering`
/// asks for: `dart:`, then `package:`, then relative, each sorted, with the
/// exports after the imports. Left alone when comments or annotations sit
/// between the directives (a comment before the first one is the file's).
String sortDirectives(String source) {
  final unit = parse(source);
  final directives = [
    for (final d in unit.directives)
      if (d is ImportDirective || d is ExportDirective) d,
  ];
  if (directives.length < 2) return source;
  for (final (i, d) in directives.indexed) {
    if (d.metadata.isNotEmpty ||
        (i > 0 && d.beginToken.precedingComments != null)) {
      return source;
    }
    if (i > 0 &&
        source.substring(directives[i - 1].end, d.offset).trim().isNotEmpty) {
      return source;
    }
  }
  String block(Iterable<Directive> group) {
    int section(Directive d) {
      final uri = (d as UriBasedDirective).uri.stringValue ?? '';
      return uri.startsWith('dart:')
          ? 0
          : uri.startsWith('package:')
          ? 1
          : 2;
    }

    final sections = <int, List<Directive>>{};
    for (final d in group) {
      (sections[section(d)] ??= []).add(d);
    }
    return [
      for (final key in sections.keys.toList()..sort())
        ([...sections[key]!]..sort(
              (a, b) => (a as UriBasedDirective).uri.stringValue!.compareTo(
                (b as UriBasedDirective).uri.stringValue!,
              ),
            ))
            .map((d) => source.substring(d.offset, d.end))
            .join('\n'),
    ].join('\n\n');
  }

  final imports = directives.whereType<ImportDirective>();
  final exports = directives.whereType<ExportDirective>();
  final sorted = [
    if (imports.isNotEmpty) block(imports),
    if (exports.isNotEmpty) block(exports),
  ].join('\n\n');
  return source.replaceRange(
    directives.first.offset,
    directives.last.end,
    sorted,
  );
}
