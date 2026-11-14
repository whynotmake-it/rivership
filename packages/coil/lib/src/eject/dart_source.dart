// Just enough Dart source handling for eject: the directives at the top of
// a file and the public names a file declares. coil's sources are
// `dart format`ted, so every top-level declaration starts in column 0.
// test/architecture/eject_test.dart checks [declaredNames] against the
// analyzer for every component.

/// An `import`, `export` or `part` directive.
class Directive {
  Directive._(this.keyword, this.text, this.start, this.end);

  /// `import`, `export` or `part`.
  final String keyword;

  /// The directive's source, from the keyword to the semicolon.
  final String text;

  /// Where [text] starts in the file.
  final int start;

  /// Where [text] ends in the file.
  final int end;

  /// Every URI in the directive, including conditional ones.
  List<String> get uris => [
    for (final m in _string.allMatches(text)) m.group(2)!,
  ];

  /// The names after `show`, or null if there is no `show`.
  Set<String>? get shown => _combinator('show');

  /// The names after `hide`.
  Set<String> get hidden => _combinator('hide') ?? const {};

  Set<String>? _combinator(String keyword) {
    final m =
        RegExp(
          '\\b$keyword\\s+([\\w\\s,]+?)\\s*(?=\\b(?:show|hide)\\b|;)',
        ).firstMatch(
          text.replaceAll(_string, "''"),
        );
    if (m == null) return null;
    return {
      for (final name in m.group(1)!.split(RegExp(r'[\s,]+')))
        if (name.isNotEmpty) name,
    };
  }

  /// This directive with each URI replaced by [rewrite]'s result.
  String rewritten(String Function(String uri) rewrite) =>
      text.replaceAllMapped(
        _string,
        (m) => '${m.group(1)}${rewrite(m.group(2)!)}${m.group(1)}',
      );

  static final _string = RegExp(r'''(['"])([^'"]*)\1''');
}

final _directive = RegExp(r'^(import|export|part)\b[^;]*;', multiLine: true);

/// The `import`, `export` and `part` directives in [source].
List<Directive> directivesOf(String source) => [
  for (final m in _directive.allMatches(source))
    Directive._(m.group(1)!, m.group(0)!, m.start, m.end),
];

/// [source] with every directive's URIs passed through [rewrite].
String rewriteDirectives(String source, String Function(String uri) rewrite) {
  final out = StringBuffer();
  var last = 0;
  for (final d in directivesOf(source)) {
    out
      ..write(source.substring(last, d.start))
      ..write(d.rewritten(rewrite));
    last = d.end;
  }
  return (out..write(source.substring(last))).toString();
}

final _typeDeclaration = RegExp(
  r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*'
  r'(?:class|mixin|enum|typedef|extension\s+type(?:\s+const)?)\s+(\w+)',
);
final _extension = RegExp(r'^extension\s+(\w+)\s+on\b');
final _member = RegExp(
  r'^(?:(?:external|late|final|const|var)\s+)*'
  r'(?:[\w.]+(?:<.*>)?\??\s+)?'
  r'(?:get\s+|set\s+)?'
  r'(\w+)\s*(?:<[^()]*>)?\s*(?:\(|=|;)',
);
final _notADeclaration = RegExp(
  r'^(?:import|export|part|library|//|/\*|\*|@|[})\]]|\s|$)',
);

/// The public top-level names [source] declares (classes, enums, mixins,
/// extensions, typedefs, functions, variables).
Set<String> declaredNames(String source) {
  final names = <String>{};
  for (final line in source.split('\n')) {
    if (_notADeclaration.hasMatch(line)) continue;
    final name =
        (_typeDeclaration.firstMatch(line) ??
                _extension.firstMatch(line) ??
                (line.startsWith('extension ')
                    ? null
                    : _member.firstMatch(line)))
            ?.group(1);
    if (name != null && !name.startsWith('_')) names.add(name);
  }
  return names;
}
