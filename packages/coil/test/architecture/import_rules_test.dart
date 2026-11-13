// The layer rules of doc/api_guide.md §1, checked on the source files.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// Every `lib/` Dart file, relative to `lib/`, with its import/export URIs.
Map<String, List<String>> _sources() => {
  for (final file in Directory('lib').listSync(recursive: true))
    if (file is File && file.path.endsWith('.dart'))
      file.path.substring('lib/'.length): [
        for (final line in file.readAsLinesSync())
          if (_import.firstMatch(line) case final m?) m.group(1)!,
      ],
};

/// Flutter libraries below material/cupertino.
const _flutterAllowed = {
  'animation',
  'foundation',
  'gestures',
  'painting',
  'physics',
  'rendering',
  'scheduler',
  'semantics',
  'services',
  'widgets',
};

/// The one file allowed to use material_ui / cupertino_ui.
const _textFieldCore = 'src/primitives/text_field_core.dart';

/// Things components must reach through a primitive.
final _bannedInComponents = {
  'MouseRegion': RegExp(r'\bMouseRegion\('),
  'onTapDown': RegExp(r'\bonTapDown\b'),
  'HapticFeedback': RegExp(r'\bHapticFeedback\.'),
  'highlightMode': RegExp(r'\bhighlightMode\b'),
  'OverlayPortal': RegExp(r'\bOverlayPortal\b'),
  'RawMenuAnchor': RegExp(r'\bRawMenuAnchor\b'),
  'PopupRoute': RegExp(r'\bPopupRoute\b'),
  'Navigator.push': RegExp(r'\bNavigator\.(of\([^)]*\)\.)?push\b'),
  'MotionController': RegExp(r'\b(Single)?MotionController\('),
  'AnimationController': RegExp(r'\bAnimationController\b'),
  'Tween': RegExp(r'\bTween<'),
};

String _layerOf(String path) {
  if (path.startsWith('src/foundation/') || path == 'foundation.dart') {
    return 'foundation';
  }
  if (path.startsWith('src/primitives/') || path == 'primitives.dart') {
    return 'primitives';
  }
  if (path.startsWith('src/components/')) return 'components';
  return 'library';
}

/// The component a `src/components/<name>/` file belongs to.
String? _componentOf(String path) =>
    RegExp(r'^src/components/(\w+)/').firstMatch(path)?.group(1);

void main() {
  final sources = _sources();

  test('there are sources to check', () {
    expect(sources.keys, contains('foundation.dart'));
    expect(sources.keys.where((p) => _layerOf(p) == 'components'), isNotEmpty);
  });

  test('flutter imports stay below material and cupertino', () {
    final violations = <String>[
      for (final MapEntry(key: path, value: uris) in sources.entries)
        for (final uri in uris)
          if (uri.startsWith('package:flutter/') &&
              !_flutterAllowed.contains(
                uri.substring('package:flutter/'.length).split('.').first,
              ))
            '$path imports $uri',
    ];
    expect(violations, isEmpty);
  });

  test('material_ui and cupertino_ui are confined to the text-field core', () {
    final violations = <String>[
      for (final MapEntry(key: path, value: uris) in sources.entries)
        for (final uri in uris)
          if ((uri.startsWith('package:material_ui/') ||
                  uri.startsWith('package:cupertino_ui/')) &&
              path != _textFieldCore)
            '$path imports $uri',
    ];
    expect(violations, isEmpty);
  });

  test('foundation imports no primitives or components', () {
    final violations = <String>[
      for (final MapEntry(key: path, value: uris) in sources.entries)
        if (_layerOf(path) == 'foundation')
          for (final uri in uris)
            if (uri.startsWith('package:coil/') &&
                !uri.startsWith('package:coil/src/foundation/'))
              '$path imports $uri',
    ];
    expect(violations, isEmpty);
  });

  test('primitives import only foundation and primitives', () {
    final violations = <String>[
      for (final MapEntry(key: path, value: uris) in sources.entries)
        if (_layerOf(path) == 'primitives')
          for (final uri in uris)
            if (uri.startsWith('package:coil/') &&
                !uri.startsWith('package:coil/src/foundation/') &&
                !uri.startsWith('package:coil/src/primitives/') &&
                uri != 'package:coil/foundation.dart')
              '$path imports $uri',
    ];
    expect(violations, isEmpty);
  });

  test(
    'components import only public libraries and their own src/',
    () {
      final violations = <String>[
        for (final MapEntry(key: path, value: uris) in sources.entries)
          if (_componentOf(path) case final component?)
            for (final uri in uris)
              if (uri.startsWith('package:coil/src/') &&
                      !uri.startsWith(
                        'package:coil/src/components/$component/',
                      ) ||
                  // Relative imports would break when the folder is ejected.
                  !uri.contains(':') && uri.contains('..'))
                '$path imports $uri',
      ];
      expect(violations, isEmpty);
    },
  );

  test('components reach pointer, overlay and motion internals through '
      'primitives', () {
    final violations = <String>[
      for (final file in Directory('lib/src/components').listSync(
        recursive: true,
      ))
        if (file is File && file.path.endsWith('.dart'))
          for (final (n, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//'))
              for (final MapEntry(key: name, value: pattern)
                  in _bannedInComponents.entries)
                if (pattern.hasMatch(line)) '${file.path}:${n + 1} uses $name',
    ];
    expect(violations, isEmpty);
  });

  test('no Track carries a baked-in motion in components', () {
    final violations = <String>[
      for (final file in Directory('lib/src').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (RegExp(r'Track<[^>]+>\([^)]*\bmotion:').hasMatch(
            file.readAsStringSync(),
          ))
            file.path,
    ];
    expect(violations, isEmpty);
  });
}
