import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:coil/src/eject/coil_source.dart';
import 'package:coil/src/eject/dart_source.dart';
import 'package:coil/src/eject/naming.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// The ejected set: every component the app has ejected (or is ejecting),
/// where its folder is, and how the copies are named.
class EjectPlan {
  /// A plan for the components in [paths].
  EjectPlan({required this.naming, required this.paths});

  /// The app's names.
  final Naming naming;

  /// Each ejected component's folder, relative to the app root.
  final Map<String, String> paths;
}

/// A component's files as the app gets them.
class Transformed {
  Transformed._(this.files, this.uses);

  /// Each file by its path in coil's component (`src/button.dart`): its
  /// path in the app's folder and its content.
  final Map<String, ({String path, String content})> files;

  /// The other ejected components the copy refers to.
  final Set<String> uses;
}

/// Resolves coil's sources and the app's copies with the app's package
/// config, and rewrites them with the analyzer: renamed declarations and
/// references, imports pointed at the ejected copies. String literals and
/// names that only contain `Coil` are never touched.
class EjectWorkspace {
  EjectWorkspace._(this.coil, this.appRoot, this._collection);

  /// A workspace for the app at [appRoot] and the coil it resolves to.
  static Future<EjectWorkspace> open(CoilSource coil, String appRoot) async {
    final config = await findPackageConfig(Directory(appRoot));
    final flutter = config?['flutter'];
    if (config == null || flutter == null) {
      throw EjectException(
        'No package config with Flutter in it. Run `flutter pub get` first.',
      );
    }
    // One context, rooted at the app, so coil's files resolve through the
    // app's package config wherever coil is installed.
    final root = p.normalize(p.absolute(appRoot));
    final collection = AnalysisContextCollection(
      includedPaths: [root],
      sdkPath: p.normalize(
        p.join(p.fromUri(flutter.root), '../../bin/cache/dart-sdk'),
      ),
    );
    return EjectWorkspace._(coil, root, collection);
  }

  /// The installed coil, as of the last [refresh].
  CoilSource coil;

  /// The app's root folder.
  final String appRoot;

  final AnalysisContextCollection _collection;

  /// Makes the analyzer re-read coil's and the app's Dart files, which
  /// may have changed since the last operation.
  Future<void> refresh() async {
    coil = CoilSource(coil.root);
    final context = _collection.contextFor(appRoot);
    for (final dir in [p.join(coil.root, 'lib'), appRoot]) {
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is File &&
            file.path.endsWith('.dart') &&
            !p.split(file.path).contains('.dart_tool')) {
          context.changeFile(p.normalize(p.absolute(file.path)));
        }
      }
    }
    await context.applyPendingFileChanges();
  }

  Future<ResolvedUnitResult> _resolve(String path) async {
    final absolute = p.normalize(p.absolute(path));
    final result = await _collection
        .contextFor(appRoot)
        .currentSession
        .getResolvedUnit(absolute);
    if (result is! ResolvedUnitResult) {
      throw EjectException('Could not analyze $path.');
    }
    return result;
  }

  /// Resolved foundation.dart, for the app library's aliases.
  Future<LibraryElement> foundation() async =>
      (await _resolve(coil.pathOf('foundation.dart'))).libraryElement;

  /// Where coil's [libPath] of [component] goes in the app, relative to
  /// the app root.
  String appPath(EjectPlan plan, CoilComponent component, String libPath) =>
      p.posix.join(
        plan.paths[component.name]!,
        plan.naming.fileFor(component.ejectedPath(libPath)),
      );

  /// [component] from the installed coil, renamed and with its imports
  /// rewritten: its own files and other ejected components' libraries
  /// become relative imports of the copies, and the rest of coil goes
  /// through public libraries.
  Future<Transformed> transform(
    CoilComponent component,
    EjectPlan plan,
  ) async {
    coil.checkEjectable(component);
    final files = <String, ({String path, String content})>{};
    final uses = <String>{};
    for (final file in component.files) {
      final out = appPath(plan, component, file);
      String mapUri(String uri) {
        final target = coil.targetOf(file, uri);
        if (target == null) return uri;
        if (component.files.contains(target)) {
          return _relative(appPath(plan, component, target), out);
        }
        final owner = coil.ownerOfLibrary(target);
        if (owner != null && plan.paths.containsKey(owner.name)) {
          uses.add(owner.name);
          return _relative(appPath(plan, owner, target), out);
        }
        return coil.publicUriFor(target)!;
      }

      final unit = await _resolve(coil.pathOf(file));
      final rewritten = sortDirectives(
        _rewrite(unit, mapUri, plan.naming, plan.paths.keys.toSet()),
      );
      files[component.ejectedPath(file)] = (
        path: p.posix.relative(out, from: plan.paths[component.name]),
        content:
            "// Ejected from coil's ${component.name}. Edit freely; merge "
            "coil's\n"
            '// changes with `dart run coil:update ${component.name}`.\n'
            '$rewritten',
      );
    }
    uses.remove(component.name);
    return Transformed._(files, uses);
  }

  /// The app file at [path] (a copy, or its base) with references to the
  /// [added] components pointed at their new copies, as if it sat at
  /// [copyPath] (relative to the app root). Returns the new content, or
  /// null when nothing changes, and the components it now uses.
  Future<({String? content, Set<String> uses})> repoint(
    String path,
    String copyPath,
    EjectPlan plan,
    Set<String> added,
  ) async {
    final uses = <String>{};
    String mapUri(String uri) {
      if (!uri.startsWith('package:coil/')) return uri;
      final target = uri.substring('package:coil/'.length);
      final owner = coil.ownerOfLibrary(target);
      if (owner == null || !added.contains(owner.name)) return uri;
      uses.add(owner.name);
      return _relative(appPath(plan, owner, target), copyPath);
    }

    final unit = await _resolve(path);
    final rewritten = sortDirectives(
      _rewrite(unit, mapUri, plan.naming, added),
    );
    return (content: rewritten == unit.content ? null : rewritten, uses: uses);
  }

  static String _relative(String target, String from) =>
      p.posix.relative(target, from: p.posix.dirname(from));

  /// [unit] with directive URIs passed through [mapUri], and every
  /// declaration of and reference to a top-level name from [components]
  /// renamed by [naming].
  String _rewrite(
    ResolvedUnitResult unit,
    String Function(String) mapUri,
    Naming naming,
    Set<String> components,
  ) {
    final edits = <int, (int, String)>{};
    void rename(Token token, String newName) {
      if (token.lexeme != newName) {
        edits[token.offset] = (token.length, newName);
      }
    }

    for (final directive in unit.unit.directives) {
      if (directive is! NamespaceDirective) continue;
      final literals = [
        directive.uri,
        for (final c in directive.configurations) c.uri,
      ];
      var local = false;
      for (final literal in literals) {
        final uri = literal.stringValue;
        if (uri == null) continue;
        final mapped = mapUri(uri);
        local |= !mapped.contains(':');
        if (mapped != uri) {
          final quote = unit.content[literal.offset];
          edits[literal.offset] = (literal.length, '$quote$mapped$quote');
        }
      }
      // `show`/`hide` names of a library that is now a copy use app names.
      if (local) {
        for (final combinator in directive.combinators) {
          final names = switch (combinator) {
            ShowCombinator(:final shownNames) => shownNames,
            HideCombinator(:final hiddenNames) => hiddenNames,
          };
          for (final name in names) {
            if (naming.renames[name.name] case final to?) {
              rename(name.token, to);
            }
          }
        }
      }
    }

    bool renamable(Element? element) {
      final uri = element?.library?.uri;
      if (uri == null || uri.scheme != 'package') return false;
      final segments = uri.pathSegments;
      return segments.length > 4 &&
          segments[0] == 'coil' &&
          segments[1] == 'src' &&
          segments[2] == 'components' &&
          components.contains(segments[3]);
    }

    unit.unit.accept(
      _References((token, element) {
        // Only the recorded public names: private ones keep `Coil`.
        if (renamable(element) && token.lexeme == element.name) {
          if (naming.renames[element.name] case final to?) rename(token, to);
        }
      }),
    );

    var content = unit.content;
    for (final offset in edits.keys.toList()..sort((a, b) => b - a)) {
      final (length, text) = edits[offset]!;
      content = content.replaceRange(offset, offset + length, text);
    }
    return content;
  }
}

/// Reports every token that declares or refers to a top-level element:
/// declarations, type names, identifiers, constructor names and `[doc]`
/// references. Members and parameters are never reported.
class _References extends RecursiveAstVisitor<void> {
  _References(this.report);

  final void Function(Token token, Element element) report;

  void _top(Token token, Element? element) {
    final top = switch (element) {
      ConstructorElement(:final enclosingElement) => enclosingElement,
      PropertyAccessorElement(:final variable)
          when variable is TopLevelVariableElement =>
        variable,
      _ => element,
    };
    if (top != null && top.enclosingElement is LibraryElement) {
      report(token, top);
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _top(node.token, node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _top(node.name, node.element);
    super.visitNamedType(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _top(node.namePart.typeName, node.declaredFragment?.element);
    super.visitClassDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _top(node.namePart.typeName, node.declaredFragment?.element);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _top(node.namePart.typeName, node.declaredFragment?.element);
    super.visitExtensionTypeDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _top(node.name, node.declaredFragment?.element);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (node.name case final name?) {
      _top(name, node.declaredFragment?.element);
    }
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _top(node.name, node.declaredFragment?.element);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _top(node.name, node.declaredFragment?.element);
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    _top(node.name, node.declaredFragment?.element);
    super.visitFunctionTypeAlias(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _top(node.name, node.declaredFragment?.element);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.typeName case final typeName?) {
      _top(typeName.token, node.declaredFragment?.element);
    }
    super.visitConstructorDeclaration(node);
  }
}
