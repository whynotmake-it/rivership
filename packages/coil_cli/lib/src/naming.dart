import 'package:coil_cli/src/coil_source.dart';
import 'package:path/path.dart' as p;

/// Naming rules for ejected copies in the app.
///
/// Combines an optional [prefix] that replaces `Coil` in symbol names and
/// prefixes file names with explicit symbol [renames].
class Naming {
  /// Creates a [Naming] configuration with an optional [prefix] (e.g. `Acme`:
  /// `CoilButton` → `AcmeButton`, `button.dart` → `acme_button.dart`) and
  /// previously recorded [renames].
  Naming({this.prefix, Map<String, String>? renames})
    : renames = renames ?? {} {
    if (prefix case final prefix? when !_typeName.hasMatch(prefix)) {
      throw EjectException(
        '--prefix must be an UpperCamelCase identifier, like Acme. '
        'Got "$prefix".',
      );
    }
  }

  /// Prefix that replaces the `Coil` word in symbol names and prefixes file
  /// names, or `null` when keeping default Coil names.
  final String? prefix;

  /// Maps every renamed Coil symbol to its name in the app.
  ///
  /// Includes both explicit renames and names derived from [prefix] so
  /// subsequent updates reproduce the exact same symbols.
  final Map<String, String> renames;

  static final _typeName = RegExp(r'^[A-Z][A-Za-z0-9]*$');
  static final _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

  // `Coil` as a camel-case word: `CoilButton`, `showCoilModal`.
  static final _coilWord = RegExp(r'(?<![A-Z])Coil(?=[A-Z0-9_]|$)');

  /// Returns the app's symbol name for the Coil symbol [name].
  String nameFor(String name) =>
      renames[name] ??
      (prefix == null ? name : name.replaceFirst(_coilWord, prefix!));

  /// Returns the app's file path for a component file at [path] (relative to
  /// the component directory).
  String fileFor(String path) {
    if (prefix == null) return path;
    final dir = p.posix.dirname(path);
    final file = '${snakeCase(prefix!)}_${p.posix.basename(path)}';
    return dir == '.' ? file : p.posix.join(dir, file);
  }

  /// Records the app name for every symbol in [names] that changes.
  ///
  /// Validates that each entry in [explicit] (e.g. `CoilButton` →
  /// `AcmeButton`) refers to a symbol in [names], targets a valid identifier,
  /// and does not collide with another symbol.
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

/// Converts an UpperCamelCase [name] to `snake_case` (e.g. `AcmeUi` →
/// `acme_ui`).
String snakeCase(String name) => name
    .replaceAllMapped(RegExp('(?<=[a-z0-9])[A-Z]'), (m) => '_${m[0]}')
    .toLowerCase();
