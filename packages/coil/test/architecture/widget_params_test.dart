@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Visible text and icons are `Widget` parameters that the component styles
/// through `DefaultTextStyle` and `IconTheme`. A public `String` or
/// `IconData` field is allowed only when a widget can't do the job, and its
/// name says which job:
///
/// * `semanticLabel`, or any name ending in `Label` or `Labels`: for screen
///   readers;
/// * `searchText` or `searchTexts`: what typeahead and filters match.
///
/// Anything else needs an entry in [_allowed] with the reason.
final _allowed = {
  'primitives/text_field_core.dart CoilTextFieldCore.obscuringCharacter':
      'the character that hides obscured text, not a label',
  'components/input_copy/input_copy.dart CoilInputCopy.value':
      'the value that gets copied',
  'components/ask_user_questions/question.dart CoilAnswer.text':
      'what the user typed',
  'components/file_thumbnail/file_thumbnail.dart CoilFileThumbnail.name':
      'the file name: announced, and its extension is the fallback tile',
  'components/kbd/kbd.dart CoilKbd.keys':
      'key names the caps are drawn from, also read from a shortcut',
  for (final file in [
    'components/slider/slider.dart CoilSlider',
    'components/slider/range_slider.dart CoilRangeSlider',
    'components/slider/slider_core.dart SliderCore',
  ]) ...{
    '$file.semanticFormatter': 'the value as screen readers hear it',
    '$file.editFormatter': 'the text the value field edits',
  },
};

final _class = RegExp(r'^(?:\w+ )*class (\w+)');
final _field = RegExp(
  r'^  final ((?:String|IconData)\??|List<String\??>\??|String\?? Function\(.*\)\??) (\w+);',
);

bool _namedForItsJob(String name) =>
    name == 'searchText' ||
    name == 'searchTexts' ||
    name.endsWith('Label') ||
    name.endsWith('Labels');

void main() {
  test('visible text and icons are widget parameters', () {
    final violations = <String>[];
    for (final dir in ['lib/src/components', 'lib/src/primitives']) {
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path.substring('lib/src/'.length);
        String? owner;
        for (final line in file.readAsLinesSync()) {
          if (_class.firstMatch(line) case final m?) owner = m.group(1);
          final field = _field.firstMatch(line);
          if (field == null || owner == null || owner.startsWith('_')) {
            continue;
          }
          final name = field.group(2)!;
          final key = '$path $owner.$name';
          if (_namedForItsJob(name) || _allowed.containsKey(key)) {
            continue;
          }
          violations.add('$key (${field.group(1)})');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Take a Widget for visible text and icons. Keep a String only for '
          'screen readers (`semanticLabel`, `…Label`) or matching '
          '(`searchText`); otherwise allow it in widget_params_test.dart '
          'with the reason.',
    );
  });
}
