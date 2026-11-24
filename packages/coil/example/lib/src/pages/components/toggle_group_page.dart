import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const toggleGroupEntry = CatalogEntry(
  slug: 'toggle-group',
  title: 'ToggleGroup',
  group: CatalogGroup.groupedControls,
  summary:
      'A row of segments that toggle independently, for things like text '
      'formatting.',
  page: ToggleGroupPage.new,
);

class ToggleGroupPage extends StatefulWidget {
  const ToggleGroupPage({super.key});

  @override
  State<ToggleGroupPage> createState() => _ToggleGroupPageState();
}

/// How a segment labels itself in the playground.
enum _Shape {
  label('Label'),
  both('Icon and label'),
  icon('Icon only');

  const _Shape(this.name);

  final String name;
}

enum _Channel {
  email('Email', Glyph.mail),
  push('Push', Glyph.bell),
  sms('SMS', Glyph.message);

  const _Channel(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

class _ToggleGroupPageState extends State<ToggleGroupPage> {
  var _channels = {_Channel.email, _Channel.push};
  var _shape = _Shape.both;
  var _compact = false;
  var _disabled = false;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return CatalogPage(
      title: 'ToggleGroup',
      summary:
          'A row of segments that each turn on and off on their own, where '
          'selected neighbours merge into one block. For picking a single '
          'option, use Tabs or a RadioGroup instead.',
      hero: const _NoteEditor(),
      usage: '''
CoilToggleGroup<Format>(
  values: formats,
  onChanged: (values) => setState(() => formats = values),
  options: const [
    CoilOption(
      value: Format.bold,
      label: Icon(LucideIcons.bold),
      semanticLabel: 'Bold',
    ),
    CoilOption(
      value: Format.italic,
      label: Icon(LucideIcons.italic),
      semanticLabel: 'Italic',
    ),
  ],
)''',
      notes: const [
        CatalogNote(
          'Keyboard',
          'The group takes one tab stop and focus roves inside it, so Left '
              'and Right move between segments and Space toggles the focused '
              'one. The editor above also binds Ctrl or Cmd with B, I and U.',
        ),
        CatalogNote(
          'Motion',
          'Selected segments merge and split on the standard spring, and a '
              'segment whose label changes cross-fades while springing to its '
              'new width.',
        ),
        CatalogNote(
          'Accessibility',
          'Each segment is announced as a toggle button with a selected '
              'state, so an icon-only segment needs a semanticLabel on its '
              'option to be named.',
        ),
        CatalogNote(
          'Do / Don’t',
          'It fits formatting and other switches that can be on at the same '
              'time. When only one option can apply, use Tabs or a '
              'RadioGroup.',
        ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DemoSection(
              title: 'Playground',
              description:
                  'A segment shows whatever widget you give it as a label, so '
                  'it can carry text, an icon, or an icon beside its text.',
              controls: DemoControls(
                children: [
                  DemoControl.choice(
                    label: 'Segments',
                    value: _shape,
                    values: _Shape.values,
                    labelOf: (v) => v.name,
                    onChanged: (v) => setState(() => _shape = v),
                  ),
                  DemoControl.toggle(
                    label: 'Compact',
                    value: _compact,
                    onChanged: (v) => setState(() => _compact = v),
                  ),
                  DemoControl.toggle(
                    label: 'Disabled',
                    value: _disabled,
                    onChanged: (v) => setState(() => _disabled = v),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notify me by', style: text.muted.caption),
                  const SizedBox(height: 6),
                  CoilToggleGroup<_Channel>(
                    size: _compact ? CoilSize.compact : null,
                    semanticLabel: 'Notify me by',
                    values: _channels,
                    onChanged: _disabled
                        ? null
                        : (values) => setState(() => _channels = values),
                    options: [
                      for (final channel in _Channel.values)
                        CoilOption(
                          value: channel,
                          // An icon alone says nothing to a screen reader.
                          semanticLabel: _shape == _Shape.icon
                              ? channel.label
                              : null,
                          icon: _shape == _Shape.both
                              ? CatalogIcon(channel.glyph)
                              : null,
                          label: _shape == _Shape.icon
                              ? CatalogIcon(channel.glyph)
                              : Text(channel.label),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const UsageSnippet(
              code: '''
// An icon alone: semanticLabel names the segment.
CoilOption(
  value: Channel.email,
  label: Icon(LucideIcons.mail),
  semanticLabel: 'Email',
)

// An icon beside its label: the icon leads, in the label's color.
CoilOption(
  value: Channel.email,
  icon: Icon(LucideIcons.mail),
  label: Text('Email'),
)''',
            ),
          ],
        ),
      ],
    );
  }
}

enum _Format {
  bold('Bold', Glyph.bold),
  italic('Italic', Glyph.italic),
  underline('Underline', Glyph.underline),
  strike('Strikethrough', Glyph.strikethrough);

  const _Format(this.label, this.glyph);

  final String label;
  final Glyph glyph;

  int get bit => 1 << index;
}

/// Text that remembers a format for every character. It renders them as
/// styled spans and keeps them in step with the text as it is edited, so
/// typing, pasting and deleting never shift a format onto the wrong words.
class _StyledTextController extends TextEditingController {
  _StyledTextController({required String text})
    : _masks = List<int>.filled(text.length, 0, growable: true),
      super(text: text);

  /// One bit set per [_Format] for each character.
  final List<int> _masks;

  /// The formats for the next typed character after a toggle at a caret;
  /// null until then, when typing continues the formats before the caret.
  int? _pending;

  /// Applies [format] to the first [needle] in the text.
  void seed(String needle, _Format format) {
    final start = text.indexOf(needle);
    if (start < 0) return;
    for (var i = start; i < start + needle.length; i++) {
      _masks[i] |= format.bit;
    }
  }

  int _maskAt(TextSelection selection) {
    if (!selection.isValid || _masks.isEmpty) return _pending ?? 0;
    if (selection.isCollapsed) {
      if (_pending case final pending?) return pending;
      final offset = selection.baseOffset.clamp(0, _masks.length);
      return offset > 0 ? _masks[offset - 1] : _masks.first;
    }
    final start = math.min(selection.start, _masks.length);
    final end = math.min(selection.end, _masks.length);
    if (start >= end) return 0;
    var mask = _masks[start];
    for (var i = start + 1; i < end; i++) {
      mask &= _masks[i];
    }
    return mask;
  }

  /// The formats shared by the whole selection, or those a character typed
  /// at the caret would get.
  Set<_Format> get formats {
    final mask = _maskAt(selection);
    return {
      for (final format in _Format.values)
        if (mask & format.bit != 0) format,
    };
  }

  /// Turns [format] on or off for the selection, or for what is typed next
  /// when nothing is selected.
  void setFormat(_Format format, {required bool on}) {
    final selection = this.selection;
    if (!selection.isValid || selection.isCollapsed) {
      final mask = _maskAt(selection);
      _pending = on ? mask | format.bit : mask & ~format.bit;
    } else {
      for (var i = selection.start; i < selection.end; i++) {
        _masks[i] = on ? _masks[i] | format.bit : _masks[i] & ~format.bit;
      }
    }
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final old = text;
    final moved = newValue.selection != selection;
    if (newValue.text != old) {
      _edit(old, newValue.text, newValue.selection);
      _pending = null;
    } else if (moved) {
      _pending = null;
    }
    super.value = newValue;
  }

  /// Splices the masks like the text changed: the removed characters go,
  /// the inserted ones take the formats at the caret.
  void _edit(String old, String updated, TextSelection selection) {
    final limit = math.min(old.length, updated.length);
    var prefix = 0;
    while (prefix < limit &&
        old.codeUnitAt(prefix) == updated.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < limit - prefix &&
        old.codeUnitAt(old.length - 1 - suffix) ==
            updated.codeUnitAt(updated.length - 1 - suffix)) {
      suffix++;
    }
    final removed = old.length - prefix - suffix;
    final added = updated.length - prefix - suffix;
    // Several positions can explain a change in repeated text ("aaa" minus
    // one "a"); the caret says where it really happened.
    var start = prefix;
    if (selection.isValid && selection.isCollapsed) {
      final guess = selection.baseOffset - (added > 0 ? added : 0);
      if (guess >= 0 &&
          guess < start &&
          old.substring(0, guess) + updated.substring(guess, guess + added) ==
              updated.substring(0, guess + added) &&
          old.substring(guess + removed) == updated.substring(guess + added)) {
        start = guess;
      }
    }
    final inherited =
        _pending ??
        (start > 0 ? _masks[start - 1] : (_masks.isEmpty ? 0 : _masks.first));
    _masks.replaceRange(
      start,
      start + removed,
      List<int>.filled(added, inherited),
    );
  }

  TextStyle _styleOf(int mask) => TextStyle(
    fontWeight: mask & _Format.bold.bit != 0 ? FontWeight.w700 : null,
    fontStyle: mask & _Format.italic.bit != 0 ? FontStyle.italic : null,
    decoration: TextDecoration.combine([
      if (mask & (_Format.underline.bit | _composingBit) != 0)
        TextDecoration.underline,
      if (mask & _Format.strike.bit != 0) TextDecoration.lineThrough,
    ]),
  );

  static const _composingBit = 1 << 8;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (text.isEmpty || _masks.length != text.length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    int keyAt(int i) =>
        _masks[i] |
        (i >= composing.start && i < composing.end ? _composingBit : 0);
    final spans = <InlineSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || keyAt(i) != keyAt(start)) {
        spans.add(
          TextSpan(
            text: text.substring(start, i),
            style: _styleOf(keyAt(start)),
          ),
        );
        start = i;
      }
    }
    return TextSpan(style: style, children: spans);
  }
}

class _FormatIntent extends Intent {
  const _FormatIntent(this.format);

  final _Format format;
}

/// A note editor: the toolbar shows the formats at the caret or across the
/// selection, and a toggle formats the selection or what you type next.
class _NoteEditor extends StatefulWidget {
  const _NoteEditor();

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = _seeded();
  final _focus = FocusNode();

  static _StyledTextController _seeded() =>
      _StyledTextController(
          text:
              'Release notes for 2.4\n'
              'Ships on Friday. Update the changelog before tagging, and '
              'tell design about the new tabs.',
        )
        ..seed('Release notes for 2.4', _Format.bold)
        ..seed('Friday', _Format.italic)
        ..seed('Update the changelog', _Format.underline);

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle(Set<_Format> next) {
    final current = _controller.formats;
    for (final format in _Format.values) {
      if (next.contains(format) != current.contains(format)) {
        _controller.setFormat(format, on: next.contains(format));
      }
    }
    // The press took focus; the selection stayed in the controller.
    _focus.requestFocus();
  }

  void _flip(_Format format) => _controller.setFormat(
    format,
    on: !_controller.formats.contains(format),
  );

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Release note', style: text.title),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => CoilToggleGroup<_Format>(
              semanticLabel: 'Text formatting',
              values: _controller.formats,
              onChanged: _toggle,
              options: [
                for (final format in _Format.values)
                  CoilOption(
                    value: format,
                    semanticLabel: format.label,
                    label: CatalogIcon(format.glyph),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Actions(
          actions: {
            _FormatIntent: CallbackAction<_FormatIntent>(
              onInvoke: (intent) {
                _flip(intent.format);
                return null;
              },
            ),
          },
          child: CoilInput.multiline(
            controller: _controller,
            focusNode: _focus,
            minLines: 5,
            semanticLabel: 'Release note',
            placeholder: const Text('What changed in this release?'),
            shortcuts: {
              for (final (key, format) in [
                (LogicalKeyboardKey.keyB, _Format.bold),
                (LogicalKeyboardKey.keyI, _Format.italic),
                (LogicalKeyboardKey.keyU, _Format.underline),
              ]) ...{
                SingleActivator(key, control: true): _FormatIntent(format),
                SingleActivator(key, meta: true): _FormatIntent(format),
              },
            },
          ),
        ),
      ],
    );
  }
}
