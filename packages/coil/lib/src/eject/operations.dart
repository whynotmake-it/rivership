import 'dart:convert';
import 'dart:io';

import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/manifest.dart';
import 'package:path/path.dart' as p;

/// Copies [name] from [coil] into the app at [appRoot], under
/// `<into>/<component>/`, and records the pristine copy as the base for
/// later updates. Returns the component's name.
///
/// Refuses to replace an earlier eject of the same component unless
/// [force] is set.
String eject(
  CoilSource coil,
  String appRoot,
  String name, {
  String into = 'lib/coil',
  bool force = false,
}) {
  final component = coil.component(name);
  final files = coil.ejectedFiles(component);
  final manifest = Manifest.read(appRoot);
  final path = p.posix.join(into, component.name);
  final previous = manifest.components[component.name];
  final target = Directory(p.join(appRoot, previous?.path ?? path));
  if (!force && (previous != null || target.existsSync())) {
    throw EjectException(
      '${component.name} is already ejected to '
      '${p.relative(target.path, from: appRoot)}. '
      'Run `dart run coil:update ${component.name}` to merge upstream '
      'changes, or eject with --force to replace your copy.',
    );
  }
  for (final dir in [
    target,
    Directory(p.join(appRoot, '.coil', 'base', component.name)),
  ]) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  manifest.components[component.name] = EjectedComponent(
    path: path,
    files: {for (final file in files.keys) file: coil.version},
  );
  for (final MapEntry(key: file, value: source) in files.entries) {
    for (final out in [
      manifest.copy(component.name, file),
      manifest.base(component.name, file),
    ]) {
      out
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
    }
  }
  manifest
    ..write()
    ..writeLibrary(coil);
  return component.name;
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
  UpdateResult._(this.component, this.from, this.to, this.files, this.diff);

  /// The component's name.
  final String component;

  /// The base versions before the update, and the version it updated to.
  final Set<String> from;

  /// The installed coil version.
  final String to;

  /// Each file's outcome, by path inside the ejected folder.
  final Map<String, FileUpdate> files;

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
UpdateResult update(
  CoilSource coil,
  String appRoot,
  String name, {
  bool dryRun = false,
}) {
  final manifest = Manifest.read(appRoot);
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
  final upstream = coil.ejectedFiles(component);
  final from = ejected.files.values.toSet();
  final outcomes = <String, FileUpdate>{};
  final writes = <String, String?>{};
  final bases = <String, String?>{};
  final temp = Directory.systemTemp.createTempSync('coil_update');
  try {
    for (final file in {
      ...ejected.files.keys,
      ...upstream.keys,
    }.toList()..sort()) {
      final baseFile = manifest.base(name, file);
      final copyFile = manifest.copy(name, file);
      final base = ejected.files.containsKey(file) && baseFile.existsSync()
          ? baseFile.readAsStringSync()
          : null;
      final ours = copyFile.existsSync() ? copyFile.readAsStringSync() : null;
      final theirs = upstream[file];

      if (base == theirs) {
        outcomes[file] = FileUpdate.unchanged;
      } else if (theirs == null) {
        if (ours == null || ours == base) {
          outcomes[file] = FileUpdate.removed;
          writes[file] = null;
          bases[file] = null;
        } else {
          outcomes[file] = FileUpdate.removedButEdited;
        }
      } else if (ours == null) {
        if (base == null) {
          outcomes[file] = FileUpdate.added;
          writes[file] = theirs;
          bases[file] = theirs;
        } else {
          outcomes[file] = FileUpdate.deletedButChanged;
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
        outcomes[file] = clean
            ? (base == null ? FileUpdate.added : FileUpdate.merged)
            : FileUpdate.conflict;
        if (merged != ours) writes[file] = merged;
        if (clean) bases[file] = theirs;
      }
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
          ejected.files.remove(file);
        } else {
          out
            ..createSync(recursive: true)
            ..writeAsStringSync(content);
          ejected.files[file] = coil.version;
        }
      }
      manifest
        ..write()
        ..writeLibrary(coil);
    }
    return UpdateResult._(name, from, coil.version, outcomes, diff);
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
    'coil:update needs git on your PATH for its three-way merge '
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
