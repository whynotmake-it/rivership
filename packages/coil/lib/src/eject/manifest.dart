import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/naming.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One ejected file: where it lives in the app and which coil version its
/// base in `.coil/base/` came from.
class EjectedFile {
  /// A file at [path] (inside the component's folder) on a base from
  /// [version].
  EjectedFile({required this.path, required this.version});

  /// The app's path for the file, inside the component's folder.
  final String path;

  /// The coil version of its base.
  String version;
}

/// One ejected component in the [Manifest].
class EjectedComponent {
  /// A component ejected to [path].
  EjectedComponent({
    required this.path,
    required this.files,
    Set<String>? uses,
  }) : uses = uses ?? {};

  /// The ejected folder, relative to the app root (`lib/coil/button`).
  final String path;

  /// Each file, by its path in coil's component (`src/button.dart`).
  final Map<String, EjectedFile> files;

  /// The other ejected components whose copies this one refers to.
  final Set<String> uses;
}

/// `.coil/ejected.yaml`: what the app ejected, from which coil version, and
/// under which names. The pristine copies live next to it in
/// `.coil/base/<component>/`; both belong in version control, since they
/// are the base of every update.
class Manifest {
  Manifest._(this.appRoot, this.library, this.naming, this.components);

  /// The manifest of the app at [appRoot], or an empty one.
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

  /// The app's root folder.
  final String appRoot;

  /// The app library, relative to the app root, once set.
  String? library;

  /// The prefix and renames the copies use.
  Naming naming;

  /// The ejected components, by name.
  final Map<String, EjectedComponent> components;

  /// The base copy of [file] (an app path inside the folder) in
  /// [component].
  File base(String component, String file) =>
      File(p.join(appRoot, '.coil', 'base', component, file));

  /// The app's copy of [file] (an app path inside the folder) in
  /// [component].
  File copy(String component, String file) =>
      File(p.join(appRoot, components[component]!.path, file));

  /// Writes the manifest back to disk.
  void write() {
    final out = StringBuffer()
      ..writeln('# Written by `dart run coil:eject` and `coil:update`. Commit')
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

  /// Writes the app library: `package:coil/coil.dart` minus the ejected
  /// names, the ejected copies' public libraries and, with a prefix,
  /// aliases for the foundation's types ([foundation] is resolved
  /// `foundation.dart`).
  void writeLibrary(CoilSource coil, LibraryElement? foundation) {
    final libraryDir = p.dirname(p.join(appRoot, library));
    final hidden = <String>{};
    final exports = <String>[];
    for (final name in components.keys.toList()..sort()) {
      final component = coil.components[name];
      if (component == null) {
        throw EjectException(
          'coil ${coil.version} no longer has "$name", but the app ejected '
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
      ..writeln('// Generated by `dart run coil:eject`. Do not edit: eject and')
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
