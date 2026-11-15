import 'package:coil_cli/src/coil_source.dart';
import 'package:path/path.dart' as p;

/// How ejected copies are named in the app: an optional prefix that
/// replaces `Coil` in names and leads file names, and explicit renames.
class Naming {
  /// Names with [prefix] (`Acme`: `CoilButton` → `AcmeButton`,
  /// `button.dart` → `acme_button.dart`) and the [renames] already applied.
  Naming({this.prefix, Map<String, String>? renames})
    : renames = renames ?? {} {
    if (prefix case final prefix? when !_typeName.hasMatch(prefix)) {
      throw EjectException(
        '--prefix must be an UpperCamelCase identifier, like Acme. '
        'Got "$prefix".',
      );
    }
  }

  /// Replaces the `Coil` word in names and prefixes file names, or null.
  final String? prefix;

  /// Every coil name the copies use under another name. Explicit renames
  /// and names derived from [prefix] alike, so updates reuse them exactly.
  final Map<String, String> renames;

  static final _typeName = RegExp(r'^[A-Z][A-Za-z0-9]*$');
  static final _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

  // `Coil` as a camel-case word: `CoilButton`, `showCoilModal`.
  static final _coilWord = RegExp(r'(?<![A-Z])Coil(?=[A-Z0-9_]|$)');

  /// The app's name for the coil name [name].
  String nameFor(String name) =>
      renames[name] ??
      (prefix == null ? name : name.replaceFirst(_coilWord, prefix!));

  /// The app's file name for a component file at [path] (relative to the
  /// component folder).
  String fileFor(String path) {
    if (prefix == null) return path;
    final dir = p.posix.dirname(path);
    final file = '${snakeCase(prefix!)}_${p.posix.basename(path)}';
    return dir == '.' ? file : p.posix.join(dir, file);
  }

  /// Records the app name of every name in [names] that changes, after
  /// checking [explicit] renames (`CoilButton` → `AcmeButton`) refer to
  /// [names].
  void addNames(
    Iterable<String> names, {
    Map<String, String> explicit = const {},
  }) {
    final known = names.toSet();
    for (final MapEntry(key: from, value: to) in explicit.entries) {
      if (!known.contains(from)) {
        throw EjectException(
          '--rename $from=$to: none of the ejected components declares $from.',
        );
      }
      if (!_identifier.hasMatch(to)) {
        throw EjectException('--rename $from=$to: $to is not an identifier.');
      }
      if (renames[from] case final existing? when existing != to) {
        throw EjectException(
          '$from is already ejected as $existing. Renames are fixed once '
          'ejected.',
        );
      }
      renames[from] = to;
    }
    for (final name in known) {
      final to = nameFor(name);
      if (to != name) renames[name] = to;
    }
    final seen = <String, String>{};
    for (final MapEntry(key: from, value: to) in renames.entries) {
      if (seen[to] case final other?) {
        throw EjectException('$other and $from would both be named $to.');
      }
      seen[to] = from;
    }
  }
}

/// `AcmeUi` → `acme_ui`.
String snakeCase(String name) => name
    .replaceAllMapped(RegExp('(?<=[a-z0-9])[A-Z]'), (m) => '_${m[0]}')
    .toLowerCase();
