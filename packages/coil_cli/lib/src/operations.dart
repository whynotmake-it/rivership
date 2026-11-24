import 'dart:convert';
import 'dart:io';

import 'package:coil_cli/src/coil_source.dart';
import 'package:coil_cli/src/manifest.dart';
import 'package:coil_cli/src/naming.dart';
import 'package:coil_cli/src/transform.dart';
import 'package:path/path.dart' as p;

/// App-wide eject settings, fixed by the first eject.
class EjectOptions {
  /// Creates [EjectOptions]; `null` fields preserve values from the manifest.
  const EjectOptions({
    this.into,
    this.library,
    this.prefix,
    this.renames = const {},
    this.force = false,
  });

  /// Target directory for ejected component folders, relative to the app root.
  ///
  /// Defaults to `lib/<library>`.
  final String? into;

  /// Name of the generated app library (e.g. `acme` for `lib/acme.dart`).
  ///
  /// Defaults to [prefix] in `snake_case`, or `coil`.
  final String? library;

  /// Optional prefix that replaces `Coil` in symbol names and prefixes file
  /// names.
  final String? prefix;

  /// Explicit symbol renames (e.g. `CoilButton` → `AcmeButton`).
  final Map<String, String> renames;

  /// Whether to replace an earlier eject of the same component, discarding
  /// local edits.
  final bool force;
}

/// Copies the named Coil components in [names] into the app and records
/// pristine merge-base snapshots for later updates.
///
/// Returns the canonical names of the ejected components. Components ejected
/// together or separately automatically reference each other's local copies
/// (for example, an ejected dialog uses the ejected button), and previously
/// ejected copies are repointed at newly ejected ones along with their bases.
/// Throws an [EjectException] if a component is already ejected unless
/// [EjectOptions.force] is `true`.
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
        'dart run coil_cli:update ${component.name} to merge upstream '
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

/// The outcome of updating (or dry-running an update on) a single file.
enum FileUpdate {
  /// Unchanged upstream; nothing to do.
  unchanged,

  /// Upstream changes merged cleanly without conflicts.
  merged,

  /// Added upstream and copied into the app.
  added,

  /// Removed upstream and unedited in the app; deleted.
  removed,

  /// Both sides changed the same lines; the app's copy has conflict markers
  /// and the merge base remains unchanged.
  conflict,

  /// Removed upstream but edited in the app; kept as-is.
  removedButEdited,

  /// Deleted in the app but changed upstream; left deleted.
  deletedButChanged,
}

/// The result of updating a single ejected component.
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

  /// The merge-base Coil versions recorded before the update.
  final Set<String> from;

  /// The installed Coil version updated to.
  final String to;

  /// Each file's [FileUpdate] outcome, keyed by its path in Coil's component
  /// (e.g. `src/button.dart`).
  final Map<String, FileUpdate> files;

  /// Each file's path in the app, relative to the app root, keyed by its path
  /// in Coil's component.
  final Map<String, String> paths;

  /// A unified diff of the app's copy before and after when run with `dryRun`.
  final String diff;

  /// File keys that require manual resolution (conflicts and diverged
  /// deletions).
  Iterable<String> get needsAttention => files.keys.where(
    (f) => const {
      FileUpdate.conflict,
      FileUpdate.removedButEdited,
      FileUpdate.deletedButChanged,
    }.contains(files[f]),
  );
}

/// Three-way merges upstream Coil changes for [name] into the app's ejected
/// copy, file by file, against the recorded merge base.
///
/// Cleanly merged files advance their merge base and version in the manifest.
/// Conflicting files receive standard git conflict markers and keep their old
/// base so the next update merges against the same base. When [dryRun] is
/// `true`, nothing is written and [UpdateResult.diff] contains the unified
/// diff.
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
      'Coil ${coil.version} no longer has "$name"; your copy in '
      '${ejected.path} is yours to keep.',
    );
  }
  final git = _git();
  // New upstream names get the app's names the same way the old ones did,
  // in every ejected component: this copy may refer to a name another
  // component only just added, and is updated before or without it.
  manifest.naming.addNames({
    for (final other in manifest.components.keys)
      if (coil.components[other] case final source?)
        ...coil.declaredNamesOf(source),
  });
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
    'coil_cli:update requires git on your PATH for three-way merges '
    '(git merge-file). Install git and run it again.',
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
