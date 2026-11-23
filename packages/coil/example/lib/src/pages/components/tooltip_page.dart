import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:coil_example/src/widgets/shortcut.dart';
import 'package:flutter/widgets.dart';

const tooltipEntry = CatalogEntry(
  slug: 'tooltip',
  title: 'Tooltip',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Names icon-only controls on hover, focus or Android long-press.',
  page: TooltipPage.new,
);

class TooltipPage extends StatefulWidget {
  const TooltipPage({super.key});

  @override
  State<TooltipPage> createState() => _TooltipPageState();
}

class _TooltipPageState extends State<TooltipPage> {
  var _side = CoilTooltipSide.top;
  var _shortcut = true;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Tooltip',
    summary:
        'Names a control that has no label. In a group, one bubble glides '
        'from button to button instead of closing and reopening.',
    hero: const _EditorToolbar(),
    usage: '''
CoilTooltipGroup(
  child: Row(
    children: [
      CoilTooltip(
        message: const Text('Bold'),
        shortcut: CoilKbd('⌘B'),
        child: CoilButton.icon(
          variant: CoilButtonVariant.ghost,
          semanticLabel: 'Bold',
          icon: const Icon(LucideIcons.bold),
          onPressed: toggleBold,
        ),
      ),
      // …
    ],
  ),
)''',
    notes: const [
      CatalogNote(
        'Pointer',
        'The bubble opens after 200 ms of hover and closes on leave, '
            'blur, Esc or pointer-down. Within 300 ms of another closing it '
            'opens at once.',
      ),
      CatalogNote(
        'Keyboard',
        'Keyboard focus shows it immediately, so Tab through a toolbar '
            'reads out each button.',
      ),
      CatalogNote(
        'Touch',
        'On Android a long press on an icon-only button shows it above the '
            'finger and never fires the button. iOS shows none by default, '
            'and an element with a context menu opens the menu instead.',
      ),
      CatalogNote(
        'Screen readers',
        'The label is also exposed as the trigger’s tooltip semantics.',
      ),
      CatalogNote(
        "Do / Don't",
        'Tooltip icon-only controls. Never put required information in one, '
            'and never tooltip a button that already has a label.',
      ),
    ],
    children: [
      DemoSection(
        title: 'Playground',
        description: 'Hover or focus the button.',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Side',
              value: _side,
              values: CoilTooltipSide.values,
              labelOf: (v) => switch (v) {
                CoilTooltipSide.top => 'Top',
                CoilTooltipSide.bottom => 'Bottom',
                CoilTooltipSide.start => 'Start',
                CoilTooltipSide.end => 'End',
              },
              onChanged: (v) => setState(() => _side = v),
            ),
            DemoControl.toggle(
              label: 'Shortcut',
              value: _shortcut,
              onChanged: (v) => setState(() => _shortcut = v),
            ),
          ],
        ),
        child: SizedBox(
          height: 96,
          child: Center(
            child: CoilTooltip(
              side: _side,
              message: const Text('Download'),
              shortcut: _shortcut
                  ? CoilKbd(shortcutOf(context, 'S', shift: true))
                  : null,
              child: CoilButton.icon(
                variant: CoilButtonVariant.secondary,
                semanticLabel: 'Download',
                icon: const CatalogIcon(Glyph.download),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

enum _Format {
  bold('Bold', Glyph.bold, 'B'),
  italic('Italic', Glyph.italic, 'I'),
  underline('Underline', Glyph.underline, 'U'),
  strikethrough('Strikethrough', Glyph.strikethrough, 'X');

  const _Format(this.label, this.glyph, this.key);

  final String label;
  final Glyph glyph;
  final String key;
}

/// A text editor's toolbar: the format buttons toggle and style the
/// sentence below, and one bubble glides between their tooltips.
class _EditorToolbar extends StatefulWidget {
  const _EditorToolbar();

  @override
  State<_EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<_EditorToolbar> {
  final _active = <_Format>{_Format.bold};

  void _toggle(_Format format) => setState(() {
    if (!_active.add(format)) _active.remove(format);
  });

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final decorations = [
      if (_active.contains(_Format.underline)) TextDecoration.underline,
      if (_active.contains(_Format.strikethrough)) TextDecoration.lineThrough,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoilTooltipGroup(
          child: Row(
            children: [
              for (final format in _Format.values)
                CoilTooltip(
                  message: Text(format.label),
                  shortcut: CoilKbd(
                    shortcutOf(
                      context,
                      format.key,
                      shift: format == _Format.strikethrough,
                    ),
                  ),
                  child: CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    semanticLabel: format.label,
                    selected: _active.contains(format),
                    icon: CatalogIcon(format.glyph),
                    onPressed: () => _toggle(format),
                  ),
                ),
              const SizedBox(width: 8),
              CoilTooltip(
                message: const Text('Add link'),
                shortcut: CoilKbd(shortcutOf(context, 'L')),
                child: CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  semanticLabel: 'Add link',
                  icon: const CatalogIcon(Glyph.link),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ship the new onboarding on Friday, after the design review.',
          style: text.body.copyWith(
            fontWeight: _active.contains(_Format.bold)
                ? FontWeight.w700
                : text.body.fontWeight,
            fontStyle: _active.contains(_Format.italic)
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: TextDecoration.combine(decorations),
          ),
        ),
      ],
    );
  }
}
