import 'dart:io';

import 'package:coil/src/eject/dart_source.dart';
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

  static const _notComponents = {'coil.dart', 'testing.dart'};

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
        for (final d in directivesOf(_read(name)))
          for (final uri in d.uris)
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
      'coil has no component "$name". See `dart run coil:eject --list`.',
    );
  }

  /// The public names [component]'s libraries export, which the app library
  /// hides from `package:coil/coil.dart`.
  Set<String> exportedNames(CoilComponent component) => {
    for (final library in component.libraries) ..._exports(library, component),
  };

  Set<String> _exports(String libPath, CoilComponent component) {
    final names = {
      if (component.sources.contains(libPath)) ...declaredNames(_read(libPath)),
    };
    for (final d in directivesOf(_read(libPath))) {
      if (d.keyword != 'export') continue;
      final target = _resolve(libPath, d.uris.first);
      if (target == null || !component.files.contains(target)) continue;
      final exported = _exports(target, component);
      final shown = d.shown;
      names.addAll(
        exported.where(
          (n) => (shown == null || shown.contains(n)) && !d.hidden.contains(n),
        ),
      );
    }
    return names;
  }

  /// [uri] from the coil file [from], as a path relative to `lib/`, or null
  /// if it points outside coil.
  String? _resolve(String from, String uri) {
    if (uri.startsWith('package:coil/')) {
      return uri.substring('package:coil/'.length);
    }
    if (uri.contains(':')) return null;
    final path = p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
    return path.startsWith('../') ? null : path;
  }

  /// The shared library that exports all of the foundation or primitive
  /// file at [libPath], if any. A file exported with `show` or `hide` has
  /// private parts, so importing it directly is not ejectable.
  String? _sharedLibraryFor(String libPath) {
    for (final library in sharedLibraries) {
      for (final d in directivesOf(_read(library))) {
        if (d.keyword == 'export' &&
            _resolve(library, d.uris.first) == libPath &&
            d.shown == null &&
            d.hidden.isEmpty) {
          return library;
        }
      }
    }
    return null;
  }

  /// [component]'s files as they look once ejected, keyed by their path
  /// inside the ejected folder. Imports of the component's own files become
  /// relative, everything else in coil goes through a public library.
  ///
  /// Throws an [EjectException] listing every import that has no public
  /// equivalent: another component's `src/`, or a primitive that
  /// `primitives.dart` doesn't export.
  Map<String, String> ejectedFiles(CoilComponent component) {
    final problems = <String>[];
    final files = <String, String>{};
    for (final file in component.files) {
      final out = component.ejectedPath(file);
      String rewrite(String uri) {
        final target = _resolve(file, uri);
        if (target == null) return uri;
        if (component.files.contains(target)) {
          return p.posix.relative(
            component.ejectedPath(target),
            from: p.posix.dirname(out),
          );
        }
        if (!target.startsWith('src/')) return 'package:coil/$target';
        if (!_exists(target)) {
          problems.add('lib/$file: $uri does not exist');
          return uri;
        }
        if (_sharedLibraryFor(target) case final library?) {
          return 'package:coil/$library';
        }
        problems.add(
          target.startsWith('src/components/')
              ? 'lib/$file reaches into another component: $uri. '
                    "Import that component's public library instead."
              : 'lib/$file imports $uri, which no public library fully '
                    'exports.',
        );
        return uri;
      }

      final source = _read(file);
      for (final d in directivesOf(source)) {
        if (d.keyword == 'part') {
          problems.add('lib/$file uses `part`, which eject cannot copy.');
        }
      }
      files[out] =
          '// Ejected from coil (${component.name}). Edit freely; '
          'merge upstream changes with\n'
          '// `dart run coil:update ${component.name}`.\n'
          '${rewriteDirectives(source, rewrite)}';
    }
    if (problems.isNotEmpty) {
      throw EjectException(
        'coil ${component.name} cannot be ejected as-is. This is a bug in '
        'coil; please report it:\n${problems.map((e) => '  - $e').join('\n')}',
      );
    }
    return files;
  }
}
