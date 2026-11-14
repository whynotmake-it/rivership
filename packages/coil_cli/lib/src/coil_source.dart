import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:coil_cli/src/dart_source.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Thrown when a component can't be ejected or updated. The message is
/// meant for the person running the CLI.
class EjectException implements Exception {
  /// An error with [message].
  EjectException(this.message);

  /// What went wrong and what to do about it.
  final String message;

  @override
  String toString() => message;
}

/// A component: one `lib/src/components/<name>/` folder and the public
/// libraries that export it.
class CoilComponent {
  CoilComponent._(this.name, this.libraries, this.sources);

  /// The folder name, which is also the name the CLI takes.
  final String name;

  /// Its public libraries, relative to `lib/` (`button.dart`).
  final List<String> libraries;

  /// Its source files, relative to `lib/` (`src/components/button/…`).
  final List<String> sources;

  /// Every file eject copies, relative to `lib/`.
  List<String> get files => [...libraries, ...sources];

  /// Where [libPath] lands inside the ejected folder: public libraries at
  /// the top, sources under `src/`.
  String ejectedPath(String libPath) => libraries.contains(libPath)
      ? libPath
      : p.posix.join('src', p.posix.relative(libPath, from: _dir));

  String get _dir => 'src/components/$name';
}

/// The installed coil package, read from its `lib/` folder.
class CoilSource {
  /// The coil package at [root] (the folder with `pubspec.yaml`).
  CoilSource(this.root)
    : version =
          (loadYaml(File(p.join(root, 'pubspec.yaml')).readAsStringSync())
                  as YamlMap)['version']
              as String;

  /// The package root.
  final String root;

  /// The version in coil's pubspec.
  final String version;

  String get _lib => p.join(root, 'lib');

  /// The libraries that make up coil's shared API, which ejected code keeps
  /// importing from the package.
  static const sharedLibraries = ['foundation.dart', 'primitives.dart'];

  static const _notComponents = {'coil.dart'};

  String _read(String libPath) =>
      File(p.join(_lib, libPath)).readAsStringSync();

  bool _exists(String libPath) => File(p.join(_lib, libPath)).existsSync();

  /// Every component, by name.
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
          'in coil.',
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

  /// The component called [name], or the one that owns the public library
  /// `<name>.dart`.
  CoilComponent component(String name) {
    if (components[name] case final component?) return component;
    for (final component in components.values) {
      if (component.libraries.contains('$name.dart')) return component;
    }
    throw EjectException(
      'coil has no component "$name". See `dart run coil_cli:eject --list`.',
    );
  }

  final _units = <String, CompilationUnit>{};

  /// The parsed coil file at [libPath] (relative to `lib/`).
  CompilationUnit unit(String libPath) =>
      _units[libPath] ??= parse(_read(libPath));

  /// The absolute path of the coil file at [libPath].
  String pathOf(String libPath) => p.join(_lib, libPath);

  /// The public names [component]'s libraries export, which the app library
  /// hides from `package:coil/coil.dart`.
  Set<String> exportedNames(CoilComponent component) => {
    for (final library in component.libraries) ..._exports(library, component),
  };

  /// Every public top-level name [component]'s files declare, exported or
  /// not. A prefix renames all of them.
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

  /// [uri] from the coil file [from], as a path relative to `lib/`, or null
  /// if it points outside coil.
  String? targetOf(String from, String uri) {
    if (uri.startsWith('package:coil/')) {
      return uri.substring('package:coil/'.length);
    }
    if (uri.contains(':')) return null;
    final path = p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
    return path.startsWith('../') ? null : path;
  }

  /// The component whose public library is [libPath], if any.
  CoilComponent? ownerOfLibrary(String libPath) {
    for (final component in components.values) {
      if (component.libraries.contains(libPath)) return component;
    }
    return null;
  }

  /// The public URI that stands for the coil file [target] in ejected code:
  /// a public library as itself, a foundation or primitive file as the
  /// shared library that exports all of it. Null if there is none.
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

  /// Why [component] can't be ejected as it is: imports of another
  /// component's `src/`, of private primitives, or `part` files. Empty when
  /// it can.
  List<String> problemsOf(CoilComponent component) => [
    for (final file in component.files)
      for (final (d, uri) in directiveUris(unit(file)))
        if (d is PartDirective || d is PartOfDirective)
          'lib/$file uses `part`, which eject cannot copy.'
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

  /// Throws an [EjectException] listing [component]'s [problemsOf].
  void checkEjectable(CoilComponent component) {
    final problems = problemsOf(component);
    if (problems.isEmpty) return;
    throw EjectException(
      'coil ${component.name} cannot be ejected as-is. This is a bug in '
      'coil; please report it:\n${problems.map((e) => '  - $e').join('\n')}',
    );
  }
}
