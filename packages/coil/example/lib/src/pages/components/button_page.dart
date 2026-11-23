import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';

const buttonEntry = CatalogEntry(
  slug: 'button',
  title: 'Button',
  group: CatalogGroup.leafControls,
  summary: 'Five variants, icons, loading, selected and compact.',
  page: ButtonPage.new,
);

class ButtonPage extends StatefulWidget {
  const ButtonPage({super.key});

  @override
  State<ButtonPage> createState() => _ButtonPageState();
}

enum _Icon {
  none('None'),
  leading('Leading'),
  trailing('Trailing'),
  only('Icon only');

  const _Icon(this.label);

  final String label;
}

enum _State {
  enabled('Enabled'),
  loading('Loading'),
  selected('Selected'),
  disabled('Disabled');

  const _State(this.label);

  final String label;
}

class _ButtonPageState extends State<ButtonPage> {
  var _variant = CoilButtonVariant.primary;
  var _size = CoilSize.regular;
  var _icon = _Icon.leading;
  var _state = _State.enabled;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Button',
    summary:
        'Buttons respond to a mouse, a finger and the keyboard alike. When '
        'you press one, its fill draws in by a pixel on each side, and the '
        'focus ring appears only when you move to it with Tab.',
    hero: const _ReleaseCard(),
    usage: '''
CoilButton(
  loading: publishing,
  onPressed: publish,
  child: Text(published ? 'Published' : 'Publish'),
)''',
    children: [
      DemoSection(
        title: 'Playground',
        controls: DemoControls(
          children: [
            DemoControl.choice(
              label: 'Variant',
              value: _variant,
              values: CoilButtonVariant.values,
              labelOf: _variantName,
              onChanged: (v) => setState(() => _variant = v),
            ),
            DemoControl.choice(
              label: 'Icon',
              value: _icon,
              values: _Icon.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _icon = v),
            ),
            DemoControl.choice(
              label: 'State',
              value: _state,
              values: _State.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _state = v),
            ),
            DemoControl.toggle(
              label: 'Compact',
              value: _size == CoilSize.compact,
              onChanged: (v) => setState(
                () => _size = v ? CoilSize.compact : CoilSize.regular,
              ),
            ),
          ],
        ),
        child: SizedBox(
          height: 96,
          child: Center(child: _playground()),
        ),
      ),
      DemoSection(
        title: 'Variants',
        description:
            'Use one primary button per view. A destructive action gets a '
            'red tint rather than a solid red fill.',
        child: DemoWrap(
          children: [
            for (final variant in CoilButtonVariant.values)
              CoilButton(
                variant: variant,
                onPressed: () {},
                child: Text(_labelFor(variant)),
              ),
          ],
        ),
      ),
      DemoSection(
        title: 'Compact',
        description:
            'The compact size is one step denser, for toolbars and filter '
            'bars.',
        child: DemoWrap(
          children: [
            for (final variant in CoilButtonVariant.values)
              CoilButton(
                size: CoilSize.compact,
                variant: variant,
                onPressed: () {},
                child: Text(_labelFor(variant)),
              ),
            CoilButton.icon(
              size: CoilSize.compact,
              variant: CoilButtonVariant.ghost,
              icon: const CatalogIcon(Glyph.search),
              semanticLabel: 'Search',
              onPressed: () {},
            ),
          ],
        ),
      ),
    ],
  );

  Widget _playground() {
    final onPressed = _state == _State.disabled ? null : () {};
    final glyph = switch (_variant) {
      CoilButtonVariant.destructive => Glyph.trash,
      CoilButtonVariant.primary => Glyph.send,
      _ => Glyph.download,
    };
    if (_icon == _Icon.only) {
      return CoilButton.icon(
        variant: _variant,
        size: _size,
        loading: _state == _State.loading,
        selected: _state == _State.selected,
        semanticLabel: _labelFor(_variant),
        icon: CatalogIcon(glyph),
        onPressed: onPressed,
      );
    }
    return CoilButton(
      variant: _variant,
      size: _size,
      loading: _state == _State.loading,
      selected: _state == _State.selected,
      leading: _icon == _Icon.leading ? CatalogIcon(glyph) : null,
      trailing: _icon == _Icon.trailing
          ? const CatalogIcon(Glyph.arrowRight)
          : null,
      onPressed: onPressed,
      child: Text(_labelFor(_variant)),
    );
  }

  static String _variantName(CoilButtonVariant variant) => switch (variant) {
    CoilButtonVariant.primary => 'Primary',
    CoilButtonVariant.secondary => 'Secondary',
    CoilButtonVariant.tertiary => 'Tertiary',
    CoilButtonVariant.ghost => 'Ghost',
    CoilButtonVariant.destructive => 'Destructive',
  };

  static String _labelFor(CoilButtonVariant variant) => switch (variant) {
    CoilButtonVariant.primary => 'Publish',
    CoilButtonVariant.secondary => 'Duplicate',
    CoilButtonVariant.tertiary => 'Export',
    CoilButtonVariant.ghost => 'Skip',
    CoilButtonVariant.destructive => 'Delete project',
  };
}

/// A release about to go out: the one primary, its quieter neighbors, and
/// the label and width springing as it publishes.
class _ReleaseCard extends StatefulWidget {
  const _ReleaseCard();

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

enum _Phase { draft, publishing, published }

class _ReleaseCardState extends State<_ReleaseCard> {
  var _phase = _Phase.draft;
  var _liked = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _publish() {
    setState(() => _phase = _Phase.publishing);
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _phase = _Phase.published);
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() => _phase = _Phase.draft);
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).buttonGap;
    final published = _phase == _Phase.published;
    final foreground = CoilTheme.of(context).colors.foreground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('v2.4.0', style: text.title)),
            CoilBadge(
              variant: CoilBadgeVariant.dot,
              color: published ? CoilBadgeColor.green : CoilBadgeColor.amber,
              child: Text(published ? 'Live' : 'Draft'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Springier sheets, a phone drawer and 12 fixes.',
          style: text.muted.body,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CoilButton(
              loading: _phase == _Phase.publishing,
              leading: published ? const CatalogIcon(Glyph.check) : null,
              onPressed: switch (_phase) {
                _Phase.draft => _publish,
                _Phase.publishing => null,
                _Phase.published => _reset,
              },
              child: Text(switch (_phase) {
                _Phase.draft => 'Publish',
                _Phase.publishing => 'Publishing',
                _Phase.published => 'Published',
              }),
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () {},
              child: const Text('Preview'),
            ),
            // The label and the heart change together: the count
            // cross-fades while the button springs to its new width, and
            // the heart fills on its own spring.
            CoilButton(
              variant: CoilButtonVariant.ghost,
              semanticLabel: _liked ? 'Unlike, 25 likes' : 'Like, 24 likes',
              // Liked, the heart and the count take the foreground color
              // instead of the ghost's muted rest.
              leading: IconTheme.merge(
                data: IconThemeData(color: _liked ? foreground : null),
                child: HeartGlyph(filled: _liked),
              ),
              onPressed: () => setState(() => _liked = !_liked),
              child: Text(
                _liked ? '25' : '24',
                style: _liked ? TextStyle(color: foreground) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
