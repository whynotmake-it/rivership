import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:coil_cli/src/dart_source.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Thrown when a component cannot be ejected or updated.
///
/// The [message] is written for the person running the CLI.
class EjectException implements Exception {
  /// Creates an [EjectException] with [message].
  EjectException(this.message);

  /// Describes what went wrong and how to resolve it.
  final String message;

  @override
  String toString() => message;
}

/// A Coil component: one `lib/src/components/<name>/` directory and the public
/// libraries that export it.
class CoilComponent {
  CoilComponent._(this.name, this.libraries, this.sources);

  /// The component directory name, which is also the name accepted by the CLI.
  final String name;

  /// Public libraries that export this component, relative to `lib/` (e.g.
  /// `button.dart`).
  final List<String> libraries;

  /// Source files inside this component, relative to `lib/` (e.g.
  /// `src/components/button/...`).
  final List<String> sources;

  /// All files copied when ejecting this component, relative to `lib/`.
  List<String> get files => [...libraries, ...sources];

  /// Returns where [libPath] lands inside the ejected component directory.
  ///
  /// Public libraries sit at the top level; source files live under `src/`.
  String ejectedPath(String libPath) => libraries.contains(libPath)
      ? libPath
      : p.posix.join('src', p.posix.relative(libPath, from: _dir));

  String get _dir => 'src/components/$name';
}

/// The installed Coil package, read from its `lib/` directory.
class CoilSource {
  /// Creates a [CoilSource] for the Coil package at [root] (the directory
  /// containing `pubspec.yaml`).
  CoilSource(this.root)
    : version =
          (loadYaml(File(p.join(root, 'pubspec.yaml')).readAsStringSync())
                  as YamlMap)['version']
              as String;

  /// The absolute or relative path to the Coil package root.
  final String root;

  /// The version declared in Coil's `pubspec.yaml`.
  final String version;

  String get _lib => p.join(root, 'lib');

  /// Libraries that make up Coil's shared API, which ejected code continues to
  /// import from `package:coil`.
  static const sharedLibraries = ['foundation.dart', 'primitives.dart'];

  static const _notComponents = {'coil.dart'};

  String _read(String libPath) =>
      File(p.join(_lib, libPath)).readAsStringSync();

  bool _exists(String libPath) => File(p.join(_lib, libPath)).existsSync();

  /// All components discovered in this Coil package, keyed by name.
  late final Map<String, CoilComponent> components = () {
    final libraries = <String, List<String>>{};
    for (final file in Directory(_lib).listSync()) {
      final name = p.basename(file.path);
      if (file is! File ||
          !name.endsWith('.dart') ||
          _notComponents.contains(name) ||
          sharedLibraries.contains(name)) {
        continue;
      }
      final owners = {
        for (final (_, uri) in directiveUris(unit(name)))
          if (RegExp(r'^src/components/(\w+)/').firstMatch(uri) case final m?)
            m.group(1)!,
      };
      if (owners.length != 1) {
        throw EjectException(
          'lib/$name should export exactly one component, but exports '
          '${owners.isEmpty ? 'none' : owners.join(' and ')}. This is a bug '
          'in Coil.',
        );
      }
      (libraries[owners.single] ??= []).add(name);
    }
    return {
      for (final name in libraries.keys.toList()..sort())
        name: CoilComponent._(
          name,
          libraries[name]!..sort(),
          [
            for (final file in Directory(
              p.join(_lib, 'src', 'components', name),
            ).listSync(recursive: true))
              if (file is File && file.path.endsWith('.dart'))
                p.posix.joinAll(p.split(p.relative(file.path, from: _lib))),
          ]..sort(),
        ),
    };
  }();

  /// Returns the [CoilComponent] named [name], or the one that owns the public
  /// library `<name>.dart`.
  ///
  /// Throws an [EjectException] if no matching component exists.
  CoilComponent component(String name) {
    if (components[name] case final component?) return component;
    for (final component in components.values) {
      if (component.libraries.contains('$name.dart')) return component;
    }
    throw EjectException(
      'Coil has no component "$name". Run dart run coil_cli:eject --list to '
      'see available components.',
    );
  }

  final _units = <String, CompilationUnit>{};

  /// Returns the parsed [CompilationUnit] for the Coil file at [libPath]
  /// (relative to `lib/`).
  CompilationUnit unit(String libPath) =>
      _units[libPath] ??= parse(_read(libPath));

  /// Returns the filesystem path of the Coil file at [libPath].
  String pathOf(String libPath) => p.join(_lib, libPath);

  /// Returns the public names exported by [component]'s libraries, which the
  /// generated app library hides from `package:coil/coil.dart`.
  Set<String> exportedNames(CoilComponent component) => {
    for (final library in component.libraries) ..._exports(library, component),
  };

  /// Returns every public top-level name declared by [component]'s source
  /// files, whether exported or not.
  ///
  /// A prefix renames all of these symbols.
  Set<String> declaredNamesOf(CoilComponent component) => {
    for (final file in component.sources) ...declaredNames(unit(file)),
  };

  Set<String> _exports(String libPath, CoilComponent component) {
    final names = {
      if (component.sources.contains(libPath)) ...declaredNames(unit(libPath)),
    };
    for (final (d, uri) in directiveUris(unit(libPath))) {
      if (d is! ExportDirective) continue;
      final target = targetOf(libPath, uri);
      if (target == null || !component.files.contains(target)) continue;
      final shown = shownNames(d);
      final hidden = hiddenNames(d);
      names.addAll(
        _exports(target, component).where(
          (n) => (shown == null || shown.contains(n)) && !hidden.contains(n),
        ),
      );
    }
    return names;
  }

  /// Resolves [uri] from the Coil file [from] to a path relative to `lib/`.
  ///
  /// Returns `null` if [uri] points outside the `coil` package.
  String? targetOf(String from, String uri) {
    if (uri.startsWith('package:coil/')) {
      return uri.substring('package:coil/'.length);
    }
    if (uri.contains(':')) return null;
    final path = p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
    return path.startsWith('../') ? null : path;
  }

  /// Returns the [CoilComponent] whose public library is [libPath], if any.
  CoilComponent? ownerOfLibrary(String libPath) {
    for (final component in components.values) {
      if (component.libraries.contains(libPath)) return component;
    }
    return null;
  }

  /// Returns the public `package:coil/...` URI that represents [target] in
  /// ejected code, or `null` if none exists.
  ///
  /// Public libraries map to themselves; foundation and primitive source files
  /// map to the shared library in [sharedLibraries] that exports them without
  /// `show` or `hide` combinators.
  String? publicUriFor(String target) {
    if (!target.startsWith('src/')) {
      return _exists(target) ? 'package:coil/$target' : null;
    }
    for (final library in sharedLibraries) {
      for (final (d, uri) in directiveUris(unit(library))) {
        // A file exported with `show` or `hide` has private parts, so
        // importing it directly is not ejectable.
        if (d is ExportDirective &&
            targetOf(library, uri) == target &&
            d.combinators.isEmpty) {
          return 'package:coil/$library';
        }
      }
    }
    return null;
  }

  /// Returns descriptions of any issues that prevent [component] from being
  /// ejected cleanly.
  ///
  /// Flags imports of another component's `src/`, private primitives, and
  /// `part` directives. Returns an empty list when [component] is ejectable.
  List<String> problemsOf(CoilComponent component) => [
    for (final file in component.files)
      for (final (d, uri) in directiveUris(unit(file)))
        if (d is PartDirective || d is PartOfDirective)
          'lib/$file uses part directives, which eject cannot copy.'
        else if (targetOf(file, uri) case final target?
            when !component.files.contains(target) &&
                publicUriFor(target) == null)
          _problem(file, uri, target),
  ];

  static String _problem(String file, String uri, String target) =>
      target.startsWith('src/components/')
      ? 'lib/$file reaches into another component: $uri. '
            "Import that component's public library instead."
      : 'lib/$file imports $uri, which no public library fully exports.';

  /// Throws an [EjectException] if [problemsOf] reports any issues for
  /// [component].
  void checkEjectable(CoilComponent component) {
    final problems = problemsOf(component);
    if (problems.isEmpty) return;
    throw EjectException(
      'Coil component ${component.name} cannot be ejected as-is. This is a '
      'bug in Coil; please report it:\n'
      '${problems.map((e) => '  - $e').join('\n')}',
    );
  }
}
