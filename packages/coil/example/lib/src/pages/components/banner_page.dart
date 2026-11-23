import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

const bannerEntry = CatalogEntry(
  slug: 'banner',
  title: 'Banner',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A page-level message that can be dismissed.',
  page: BannerPage.new,
);

const _infoGlyph = Glyph(LucideIcons300.info, LucideIcons400.info);
const _successGlyph = Glyph(
  LucideIcons300.circleCheck,
  LucideIcons400.circleCheck,
);
const _warningGlyph = Glyph(
  LucideIcons300.triangleAlert,
  LucideIcons400.triangleAlert,
);
const _errorGlyph = Glyph(
  LucideIcons300.circleAlert,
  LucideIcons400.circleAlert,
);

typedef _Message = ({
  String name,
  Glyph glyph,
  String title,
  String description,
  String action,
});

_Message _messageFor(CoilBannerStatus status) => switch (status) {
  CoilBannerStatus.neutral => (
    name: 'Neutral',
    glyph: Glyph.folder,
    title: 'Workspace archived',
    description: 'It is read-only until someone restores it.',
    action: 'Restore',
  ),
  CoilBannerStatus.info => (
    name: 'Info',
    glyph: _infoGlyph,
    title: 'Scheduled maintenance',
    description: 'Saturday, 02:00 to 04:00 UTC. Editing pauses briefly.',
    action: 'Details',
  ),
  CoilBannerStatus.success => (
    name: 'Success',
    glyph: _successGlyph,
    title: 'Domain verified',
    description: 'Mail from example.com is now signed.',
    action: 'View records',
  ),
  CoilBannerStatus.warning => (
    name: 'Warning',
    glyph: _warningGlyph,
    title: 'Your card expires in May',
    description: 'Update it before your next invoice on 1 Dec.',
    action: 'Update card',
  ),
  CoilBannerStatus.destructive => (
    name: 'Error',
    glyph: _errorGlyph,
    title: 'Sync failed',
    description: 'Three files could not upload. Check your connection.',
    action: 'Retry',
  ),
};

class BannerPage extends StatefulWidget {
  const BannerPage({super.key});

  @override
  State<BannerPage> createState() => _BannerPageState();
}

class _BannerPageState extends State<BannerPage> {
  var _status = CoilBannerStatus.info;
  var _variant = CoilBannerVariant.plain;
  var _description = true;
  var _actions = true;
  var _shown = true;

  @override
  Widget build(BuildContext context) {
    final message = _messageFor(_status);
    return CatalogPage(
      title: 'Banner',
      summary:
          'A message that sits over a page until it is dealt with. Dismissing '
          'only asks the page to remove it; the page decides.',
      hero: const _BillingPage(),
      usage: '''
CoilBanner(
  status: CoilBannerStatus.warning,
  variant: CoilBannerVariant.tinted,
  visible: showNotice,
  icon: Icon(Icons.warning),
  title: Text('Your card expires in May'),
  description: Text('Update it before your next invoice.'),
  actions: [CoilButton(onPressed: update, child: Text('Update card'))],
  onDismissRequested: () => setState(() => showNotice = false),
)''',
      notes: const [
        CatalogNote(
          'Touch',
          'Swipe a banner sideways to dismiss it. The close button gets a '
              '44 hit target.',
        ),
        CatalogNote(
          'Motion',
          'Appearing opens the row on standard, then the banner fades and '
              'scales in from the top on gentle, 80 ms later. A changing '
              'description springs the height.',
        ),
        CatalogNote(
          'Accessibility',
          'A banner is a live region: polite, so screen readers announce it '
              'when it appears. The close button is labelled Dismiss.',
        ),
        CatalogNote(
          "Do / Don't",
          'Never stack more than two. Use inline feedback, not a banner, for '
              'a transient confirmation. Use placement: fixed for a bar under '
              'the safe area at the top of the viewport.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Playground',
          controls: DemoControls(
            children: [
              DemoControl.choice(
                label: 'Status',
                value: _status,
                values: CoilBannerStatus.values,
                labelOf: (v) => _messageFor(v).name,
                onChanged: (v) => setState(() => _status = v),
              ),
              DemoControl.choice(
                label: 'Variant',
                value: _variant,
                values: CoilBannerVariant.values,
                labelOf: (v) => switch (v) {
                  CoilBannerVariant.plain => 'Plain',
                  CoilBannerVariant.tinted => 'Tinted',
                },
                onChanged: (v) => setState(() => _variant = v),
              ),
              DemoControl.toggle(
                label: 'Description',
                value: _description,
                onChanged: (v) => setState(() => _description = v),
              ),
              DemoControl.toggle(
                label: 'Actions',
                value: _actions,
                onChanged: (v) => setState(() => _actions = v),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoilBanner(
                status: _status,
                variant: _variant,
                visible: _shown,
                icon: CatalogIcon(message.glyph),
                title: Text(message.title),
                description: _description ? Text(message.description) : null,
                actions: [
                  if (_actions)
                    CoilButton(
                      variant: CoilButtonVariant.secondary,
                      onPressed: () {},
                      child: Text(message.action),
                    ),
                ],
                onDismissRequested: () => setState(() => _shown = false),
              ),
              if (!_shown)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CoilButton(
                    variant: CoilButtonVariant.secondary,
                    onPressed: () => setState(() => _shown = true),
                    child: const Text('Show banner'),
                  ),
                ),
            ],
          ),
        ),
        DemoSection(
          title: 'Statuses',
          description:
              'Color only for meaning: the status hue tints the icon and, in '
              'the tinted variant, an 8 % wash behind it.',
          child: DemoColumn(
            spacing: 8,
            children: [
              for (final status in CoilBannerStatus.values)
                CoilBanner(
                  status: status,
                  variant: CoilBannerVariant.tinted,
                  icon: CatalogIcon(_messageFor(status).glyph),
                  title: Text(_messageFor(status).title),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A billing screen with a notice over its content: dismissing closes the
/// row and the content slides up; Show notice brings it back.
class _BillingPage extends StatefulWidget {
  const _BillingPage();

  @override
  State<_BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<_BillingPage> {
  var _shown = true;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).buttonGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Expanded(child: Text('Billing', style: text.title)),
              if (!_shown)
                CoilButton(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  onPressed: () => setState(() => _shown = true),
                  child: const Text('Show notice'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CoilBanner(
          status: CoilBannerStatus.warning,
          variant: CoilBannerVariant.tinted,
          visible: _shown,
          icon: const CatalogIcon(_warningGlyph),
          title: const Text('Your card expires in May'),
          description: const Text('Update it before your next invoice.'),
          actions: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () {},
              child: const Text('Update card'),
            ),
          ],
          onDismissRequested: () => setState(() => _shown = false),
        ),
        const SizedBox(height: 16),
        for (final (label, value) in const [
          ('Plan', 'Team, 5 seats'),
          ('Next invoice', '€60 on 1 Dec'),
          ('Payment method', 'Visa ending 4242'),
        ]) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: gap / 2),
            child: Row(
              children: [
                Expanded(child: Text(label, style: text.muted.body)),
                Text(value, style: text.body),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
