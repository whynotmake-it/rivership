import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:coil_cli/src/coil_source.dart';
import 'package:coil_cli/src/naming.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A single ejected file, recording its path in the app and the Coil version
/// its base snapshot in `.coil/base/` came from.
class EjectedFile {
  /// Creates an [EjectedFile] at [path] (relative to the component directory)
  /// with a merge base from Coil [version].
  EjectedFile({required this.path, required this.version});

  /// The file path in the app, relative to the component directory.
  final String path;

  /// The Coil version of this file's merge base.
  String version;
}

/// An ejected component entry in the [Manifest].
class EjectedComponent {
  /// Creates an [EjectedComponent] ejected to [path].
  EjectedComponent({
    required this.path,
    required this.files,
    Set<String>? uses,
  }) : uses = uses ?? {};

  /// The ejected component directory, relative to the app root (e.g.
  /// `lib/coil/button`).
  final String path;

  /// Each ejected file, keyed by its path in Coil's component (e.g.
  /// `src/button.dart`).
  final Map<String, EjectedFile> files;

  /// Other ejected components whose local copies this component imports.
  final Set<String> uses;
}

/// Represents `.coil/ejected.yaml`: what the app ejected, from which Coil
/// version, and under which names.
///
/// Pristine merge-base snapshots live alongside it in
/// `.coil/base/<component>/`; both belong in version control as the base for
/// future updates.
class Manifest {
  Manifest._(this.appRoot, this.library, this.naming, this.components);

  /// Reads the manifest for the app at [appRoot], or returns an empty
  /// [Manifest] if none exists yet.
  factory Manifest.read(String appRoot) {
    final file = File(p.join(appRoot, path));
    if (!file.existsSync()) {
      return Manifest._(appRoot, null, Naming(), {});
    }
    final yaml = loadYaml(file.readAsStringSync()) as YamlMap? ?? YamlMap();
    final components = yaml['components'] as YamlMap? ?? YamlMap();
    return Manifest._(
      appRoot,
      yaml['library'] as String?,
      Naming(
        prefix: yaml['prefix'] as String?,
        renames: {
          for (final e in (yaml['renames'] as YamlMap? ?? YamlMap()).entries)
            e.key as String: e.value as String,
        },
      ),
      {
        for (final MapEntry(:key, :value) in components.entries)
          key as String: EjectedComponent(
            path: (value as YamlMap)['path'] as String,
            uses: {...?(value['uses'] as YamlList?)?.cast<String>()},
            files: {
              for (final f in (value['files'] as YamlMap).entries)
                f.key as String: switch (f.value) {
                  // Written before renames existed: `path: version`.
                  final YamlMap file => EjectedFile(
                    path: file['path'] as String,
                    version: '${file['version']}',
                  ),
                  final version => EjectedFile(
                    path: f.key as String,
                    version: '$version',
                  ),
                },
            },
          ),
      },
    );
  }

  /// The manifest's path, relative to the app root.
  static const path = '.coil/ejected.yaml';

  /// The app's root directory.
  final String appRoot;

  /// The generated app library path, relative to the app root, once set.
  String? library;

  /// The prefix and explicit renames used by ejected copies.
  Naming naming;

  /// The ejected components, keyed by name.
  final Map<String, EjectedComponent> components;

  /// Returns the merge-base file for [file] (an app path relative to the
  /// component directory) in [component].
  File base(String component, String file) =>
      File(p.join(appRoot, '.coil', 'base', component, file));

  /// Returns the app's local copy of [file] (an app path relative to the
  /// component directory) in [component].
  File copy(String component, String file) =>
      File(p.join(appRoot, components[component]!.path, file));

  /// Writes this manifest back to `.coil/ejected.yaml`.
  void write() {
    final out = StringBuffer()
      ..writeln(
        '# Written by `dart run coil_cli:eject` and `coil_cli:update`. Commit',
      )
      ..writeln('# it with .coil/base/, which holds the merge bases.')
      ..writeln('library: ${_quote(library!)}');
    if (naming.prefix case final prefix?) {
      out.writeln('prefix: ${_quote(prefix)}');
    }
    if (naming.renames.isNotEmpty) {
      out.writeln('renames:');
      for (final from in naming.renames.keys.toList()..sort()) {
        out.writeln('  ${_quote(from)}: ${_quote(naming.renames[from]!)}');
      }
    }
    out.writeln('components:');
    for (final name in components.keys.toList()..sort()) {
      final component = components[name]!;
      out
        ..writeln('  $name:')
        ..writeln('    path: ${_quote(component.path)}');
      if (component.uses.isNotEmpty) {
        final uses = (component.uses.toList()..sort()).map(_quote);
        out.writeln('    uses: [${uses.join(', ')}]');
      }
      out.writeln('    files:');
      for (final from in component.files.keys.toList()..sort()) {
        final file = component.files[from]!;
        out
          ..writeln('      ${_quote(from)}:')
          ..writeln('        path: ${_quote(file.path)}')
          ..writeln('        version: ${_quote(file.version)}');
      }
    }
    File(p.join(appRoot, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(out.toString());
  }

  static String _quote(String value) => "'${value.replaceAll("'", "''")}'";

  /// Writes the generated app library barrel file.
  ///
  /// Re-exports `package:coil/coil.dart` hiding the ejected symbols, exports
  /// each ejected component's public libraries, and—when a prefix is active—
  /// emits prefixed `typedef` aliases for types in [foundation] (the resolved
  /// `foundation.dart` library).
  void writeLibrary(CoilSource coil, LibraryElement? foundation) {
    final libraryDir = p.dirname(p.join(appRoot, library));
    final hidden = <String>{};
    final exports = <String>[];
    for (final name in components.keys.toList()..sort()) {
      final component = coil.components[name];
      if (component == null) {
        throw EjectException(
          'Coil ${coil.version} no longer has "$name", but the app ejected '
          'it. Remove it from ${Manifest.path} and point its imports at your '
          'copy in ${components[name]!.path}.',
        );
      }
      hidden.addAll(coil.exportedNames(component));
      for (final library in component.libraries) {
        final file = components[name]!.files[library]!.path;
        exports.add(
          p.posix.joinAll(
            p.split(
              p.relative(
                p.join(appRoot, components[name]!.path, file),
                from: libraryDir,
              ),
            ),
          ),
        );
      }
    }
    final aliases = [
      if (naming.prefix != null && foundation != null)
        for (final MapEntry(key: name, value: element)
            in foundation.exportNamespace.definedNames2.entries)
          if (_alias(name, element) case final alias?)
            if (!hidden.contains(alias.$1) &&
                !naming.renames.containsValue(alias.$1))
              alias.$2,
    ]..sort();
    final names = hidden.toList()..sort();
    final out = StringBuffer()
      ..writeln(
        '// Generated by `dart run coil_cli:eject`. Do not edit: eject and',
      )
      ..writeln('// update rewrite it. Import this library instead of')
      ..writeln('// package:coil/coil.dart to get your ejected components.')
      ..writeln();
    if (aliases.isNotEmpty) {
      out
        ..writeln('library;')
        ..writeln()
        ..writeln("import 'package:coil/coil.dart';")
        ..writeln();
    }
    out.writeln(_hiding("export 'package:coil/coil.dart'", names));
    for (final export in exports..sort()) {
      out.writeln("export '$export';");
    }
    if (aliases.isNotEmpty) {
      out
        ..writeln()
        ..writeln("// coil's foundation under the app's prefix.")
        ..writeAll(aliases, '\n')
        ..writeln();
    }
    File(p.join(appRoot, library))
      ..createSync(recursive: true)
      ..writeAsStringSync(out.toString());
  }

  /// `typedef AcmeTheme = CoilTheme;` for a foundation type, with its name.
  (String, String)? _alias(String name, Element element) {
    final List<TypeParameterElement> parameters;
    switch (element) {
      case InterfaceElement(:final typeParameters):
      case TypeAliasElement(:final typeParameters):
        parameters = typeParameters;
      default:
        return null;
    }
    final alias = naming.nameFor(name);
    if (alias == name) return null;
    String declare(TypeParameterElement t) => t.bound == null
        ? t.name!
        : '${t.name} extends ${t.bound!.getDisplayString()}';
    final declared = parameters.isEmpty
        ? ''
        : '<${parameters.map(declare).join(', ')}>';
    final used = parameters.isEmpty
        ? ''
        : '<${parameters.map((t) => t.name).join(', ')}>';
    final line = 'typedef $alias$declared = $name$used;';
    return (
      alias,
      line.length <= 80 ? line : 'typedef $alias$declared =\n    $name$used;',
    );
  }

  /// [directive] hiding [names], laid out as `dart format` does.
  static String _hiding(String directive, List<String> names) {
    if (names.isEmpty) return '$directive;';
    final oneLine = '$directive hide ${names.join(', ')};';
    if (oneLine.length <= 80) return oneLine;
    final twoLines = '    hide ${names.join(', ')};';
    if (twoLines.length <= 80) return '$directive\n$twoLines';
    final tall = names.map((n) => '        $n').join(',\n');
    return '$directive\n    hide\n$tall;';
  }
}
