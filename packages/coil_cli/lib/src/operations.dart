import 'dart:convert';
import 'dart:io';

import 'package:coil_cli/src/coil_source.dart';
import 'package:coil_cli/src/manifest.dart';
import 'package:coil_cli/src/naming.dart';
import 'package:coil_cli/src/transform.dart';
import 'package:path/path.dart' as p;

/// App-wide eject settings, fixed by the first eject.
class EjectOptions {
  /// Settings for an eject; null fields keep what the manifest has.
  const EjectOptions({
    this.into,
    this.library,
    this.prefix,
    this.renames = const {},
    this.force = false,
  });

  /// The folder the component folders go in, relative to the app root.
  /// Defaults to `lib/<library>`.
  final String? into;

  /// The app library's name (`acme` for `lib/acme.dart`). Defaults to the
  /// prefix in snake case, or `coil`.
  final String? library;

  /// Replaces `Coil` in names and leads file names.
  final String? prefix;

  /// Explicit renames, `CoilButton` → `AcmeButton`.
  final Map<String, String> renames;

  /// Whether to replace an earlier eject of the same component.
  final bool force;
}

/// Copies [names] from coil into the app and records the
/// pristine copies as the base for later updates. Returns the components'
/// names.
///
/// Components ejected together, or ejected earlier, refer to each other's
/// copies: an ejected Dialog builds the ejected Button. Copies ejected
/// earlier are re-pointed at the new ones, base included. Refuses to
/// replace an earlier eject of the same component unless forced.
Future<List<String>> eject(
  EjectWorkspace workspace,
  Iterable<String> names, {
  EjectOptions options = const EjectOptions(),
}) async {
  await workspace.refresh();
  final coil = workspace.coil;
  final appRoot = workspace.appRoot;
  final manifest = Manifest.read(appRoot);
  final components = {for (final name in names) coil.component(name)};
  if (components.isEmpty) throw EjectException('Name a component to eject.');

  final library = manifest.library;
  final naming = manifest.naming;
  if (manifest.components.isNotEmpty || library != null) {
    if (options.prefix != null && options.prefix != naming.prefix) {
      throw EjectException(
        'This app ejects with prefix ${naming.prefix ?? '(none)'}; the '
        'prefix is fixed by the first eject.',
      );
    }
    if (options.library != null &&
        'lib/${options.library}.dart' != manifest.library) {
      throw EjectException(
        'The app library is ${manifest.library}; it is fixed by the first '
        'eject.',
      );
    }
  } else {
    manifest.naming = Naming(prefix: options.prefix);
    final name =
        options.library ??
        (options.prefix == null ? 'coil' : snakeCase(options.prefix!));
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw EjectException('--library must be snake_case, like acme.');
    }
    manifest.library = 'lib/$name.dart';
  }
  final into = options.into ?? p.posix.withoutExtension(manifest.library!);

  final added = <String>{};
  for (final component in components) {
    final previous = manifest.components[component.name];
    final target = previous?.path ?? p.posix.join(into, component.name);
    if (!options.force &&
        (previous != null || Directory(p.join(appRoot, target)).existsSync())) {
      throw EjectException(
        '${component.name} is already ejected to $target. Run '
        '`dart run coil_cli:update ${component.name}` to merge upstream '
        'changes, or eject with --force to replace your copy.',
      );
    }
    added.add(component.name);
  }

  final everything = {...manifest.components.keys, ...added};
  manifest.naming.addNames(
    {
      for (final name in everything)
        ...coil.declaredNamesOf(coil.components[name]!),
    },
    explicit: options.renames,
  );
  final plan = EjectPlan(
    naming: manifest.naming,
    paths: {
      for (final name in everything)
        name: manifest.components[name]?.path ?? p.posix.join(into, name),
    },
  );

  // Point the copies already in the app at the new ones, base included,
  // before anything is written, so a failure leaves the app as it was.
  final repointed = <File, String>{};
  final linked = <String, Set<String>>{};
  for (final MapEntry(key: name, value: ejected)
      in manifest.components.entries) {
    if (added.contains(name)) continue;
    for (final file in ejected.files.values) {
      final copyPath = p.posix.join(ejected.path, file.path);
      for (final path in [
        manifest.copy(name, file.path),
        manifest.base(name, file.path),
      ]) {
        if (!path.existsSync()) continue;
        final result = await workspace.repoint(
          path.path,
          copyPath,
          plan,
          added,
        );
        if (result.content case final content?) repointed[path] = content;
        (linked[name] ??= {}).addAll(result.uses);
      }
    }
  }
  final transformed = {
    for (final component in components)
      component.name: await workspace.transform(component, plan),
  };

  for (final MapEntry(key: file, value: content) in repointed.entries) {
    file.writeAsStringSync(content);
  }
  for (final MapEntry(key: name, value: uses) in linked.entries) {
    manifest.components[name]!.uses.addAll(uses);
  }
  for (final name in added) {
    final result = transformed[name]!;
    for (final dir in [
      Directory(p.join(appRoot, plan.paths[name])),
      Directory(p.join(appRoot, '.coil', 'base', name)),
    ]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    manifest.components[name] = EjectedComponent(
      path: plan.paths[name]!,
      uses: result.uses,
      files: {
        for (final MapEntry(key: from, value: file) in result.files.entries)
          from: EjectedFile(path: file.path, version: coil.version),
      },
    );
    for (final file in result.files.values) {
      for (final out in [
        manifest.copy(name, file.path),
        manifest.base(name, file.path),
      ]) {
        out
          ..createSync(recursive: true)
          ..writeAsStringSync(file.content);
      }
    }
  }
  manifest
    ..write()
    ..writeLibrary(
      coil,
      manifest.naming.prefix == null ? null : await workspace.foundation(),
    );
  return [for (final component in components) component.name];
}

/// What an update did, or would do, to one file.
enum FileUpdate {
  /// Unchanged upstream; nothing to do.
  unchanged,

  /// Upstream changes merged without conflicts.
  merged,

  /// New upstream; copied into the app.
  added,

  /// Removed upstream and not edited in the app; deleted.
  removed,

  /// Both sides changed the same lines; the app's copy has conflict
  /// markers and the base stays where it was.
  conflict,

  /// Removed upstream but edited in the app; kept as it is.
  removedButEdited,

  /// Deleted in the app but changed upstream; left deleted.
  deletedButChanged,
}

/// The result of updating one component.
class UpdateResult {
  UpdateResult._(
    this.component,
    this.from,
    this.to,
    this.files,
    this.paths,
    this.diff,
  );

  /// The component's name.
  final String component;

  /// The base versions before the update, and the version it updated to.
  final Set<String> from;

  /// The installed coil version.
  final String to;

  /// Each file's outcome, by its path in coil's component
  /// (`src/button.dart`).
  final Map<String, FileUpdate> files;

  /// Each file's path in the app, relative to the app root, by its path in
  /// coil's component.
  final Map<String, String> paths;

  /// For a dry run, a unified diff of the app's copy before and after.
  final String diff;

  /// The files that need a person: conflicts and edits that diverged.
  Iterable<String> get needsAttention => files.keys.where(
    (f) => const {
      FileUpdate.conflict,
      FileUpdate.removedButEdited,
      FileUpdate.deletedButChanged,
    }.contains(files[f]),
  );
}

/// Three-way merges the installed coil's copy of [name] into the app's
/// ejected copy, file by file, against the recorded base.
///
/// A clean file advances its base and version in the manifest; a
/// conflicting one gets git's conflict markers and keeps its old base, so
/// the next update merges against the same base. With [dryRun] nothing is
/// written and [UpdateResult.diff] shows the change.
Future<UpdateResult> update(
  EjectWorkspace workspace,
  String name, {
  bool dryRun = false,
}) async {
  await workspace.refresh();
  final coil = workspace.coil;
  final manifest = Manifest.read(workspace.appRoot);
  final component = coil.components[name];
  final ejected = manifest.components[name];
  if (ejected == null) {
    throw EjectException(
      '$name is not ejected. Ejected: '
      '${manifest.components.keys.join(', ').ifEmpty('none')}.',
    );
  }
  if (component == null) {
    throw EjectException(
      'coil ${coil.version} has no "$name" any more; your copy in '
      '${ejected.path} is yours to keep.',
    );
  }
  final git = _git();
  // New upstream names get the app's names the same way the old ones did.
  manifest.naming.addNames(coil.declaredNamesOf(component));
  final plan = EjectPlan(
    naming: manifest.naming,
    paths: {
      for (final MapEntry(:key, :value) in manifest.components.entries)
        key: value.path,
    },
  );
  final transformed = await workspace.transform(component, plan);
  final upstream = transformed.files;
  final from = {for (final file in ejected.files.values) file.version};
  final outcomes = <String, FileUpdate>{};
  final writes = <String, String?>{};
  final bases = <String, String?>{};
  final temp = Directory.systemTemp.createTempSync('coil_update');
  try {
    final fromOf = <String, String>{};
    final paths = {
      for (final MapEntry(key: from, value: file) in ejected.files.entries)
        from: file.path,
      for (final MapEntry(key: from, value: file) in upstream.entries)
        from: ejected.files[from]?.path ?? file.path,
    };
    for (final from in paths.keys.toList()..sort()) {
      final file = paths[from]!;
      final baseFile = manifest.base(name, file);
      final copyFile = manifest.copy(name, file);
      final base = ejected.files.containsKey(from) && baseFile.existsSync()
          ? baseFile.readAsStringSync()
          : null;
      final ours = copyFile.existsSync() ? copyFile.readAsStringSync() : null;
      final theirs = upstream[from]?.content;

      if (base == theirs) {
        outcomes[from] = FileUpdate.unchanged;
      } else if (theirs == null) {
        if (ours == null || ours == base) {
          outcomes[from] = FileUpdate.removed;
          writes[file] = null;
          bases[file] = null;
        } else {
          outcomes[from] = FileUpdate.removedButEdited;
        }
      } else if (ours == null) {
        if (base == null) {
          outcomes[from] = FileUpdate.added;
          writes[file] = theirs;
          bases[file] = theirs;
        } else {
          outcomes[from] = FileUpdate.deletedButChanged;
        }
      } else {
        final (merged, clean) = _merge(
          git,
          temp,
          ours: ours,
          base: base ?? '',
          theirs: theirs,
          labels: ['app', 'base', 'coil ${coil.version}'],
        );
        outcomes[from] = clean
            ? (base == null ? FileUpdate.added : FileUpdate.merged)
            : FileUpdate.conflict;
        if (merged != ours) writes[file] = merged;
        if (clean) bases[file] = theirs;
      }
      fromOf[file] = from;
    }
    final diff = dryRun ? _diff(git, temp, manifest, name, writes) : '';
    if (!dryRun) {
      for (final MapEntry(key: file, value: content) in writes.entries) {
        final out = manifest.copy(name, file);
        if (content == null) {
          if (out.existsSync()) out.deleteSync();
        } else {
          out
            ..createSync(recursive: true)
            ..writeAsStringSync(content);
        }
      }
      for (final MapEntry(key: file, value: content) in bases.entries) {
        final out = manifest.base(name, file);
        if (content == null) {
          if (out.existsSync()) out.deleteSync();
          ejected.files.remove(fromOf[file]);
        } else {
          out
            ..createSync(recursive: true)
            ..writeAsStringSync(content);
          ejected.files[fromOf[file]!] = EjectedFile(
            path: file,
            version: coil.version,
          );
        }
      }
      ejected.uses.addAll(transformed.uses);
      manifest
        ..write()
        ..writeLibrary(
          coil,
          manifest.naming.prefix == null ? null : await workspace.foundation(),
        );
    }
    return UpdateResult._(name, from, coil.version, outcomes, {
      for (final MapEntry(key: from, value: file) in paths.entries)
        from: p.posix.join(ejected.path, file),
    }, diff);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

String _git() {
  try {
    final result = Process.runSync('git', ['--version']);
    if (result.exitCode == 0) return 'git';
  } on ProcessException {
    // Reported below.
  }
  throw EjectException(
    'coil_cli:update needs git on your PATH for its three-way merge '
    '(`git merge-file`). Install git and run it again.',
  );
}

(String, bool) _merge(
  String git,
  Directory temp, {
  required String ours,
  required String base,
  required String theirs,
  required List<String> labels,
}) {
  final files = [
    for (final (i, content) in [ours, base, theirs].indexed)
      File(p.join(temp.path, 'merge_$i'))..writeAsStringSync(content),
  ];
  final result = Process.runSync(git, [
    'merge-file',
    '-p',
    for (final label in labels) ...['-L', label],
    for (final file in files) file.path,
  ], stdoutEncoding: utf8);
  if (result.exitCode < 0 || result.exitCode > 127) {
    throw EjectException('git merge-file failed: ${result.stderr}');
  }
  return (result.stdout as String, result.exitCode == 0);
}

String _diff(
  String git,
  Directory temp,
  Manifest manifest,
  String name,
  Map<String, String?> writes,
) {
  final out = StringBuffer();
  for (final MapEntry(key: file, value: content) in writes.entries) {
    final copy = manifest.copy(name, file);
    final before = File(p.join(temp.path, 'a', file))
      ..createSync(recursive: true)
      ..writeAsStringSync(copy.existsSync() ? copy.readAsStringSync() : '');
    final after = File(p.join(temp.path, 'b', file))
      ..createSync(recursive: true)
      ..writeAsStringSync(content ?? '');
    final result = Process.runSync(
      git,
      [
        'diff',
        '--no-index',
        '--no-color',
        p.relative(before.path, from: temp.path),
        p.relative(after.path, from: temp.path),
      ],
      workingDirectory: temp.path,
      stdoutEncoding: utf8,
    );
    out.write(result.stdout);
  }
  return out.toString();
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
