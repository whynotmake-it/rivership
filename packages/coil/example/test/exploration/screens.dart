// Mock screens for the accent exploration. Not part of the catalog.
import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// Wide enough to look like a form, narrow enough to read.
const _desktopControlWidth = 360.0;

bool _isTouch(BuildContext context) =>
    CoilTheme.tierOf(context) == CoilTier.touch;

/// Pads the screen with the phone gutter; desktop content is padded by the
/// board.
Widget _gutter(BuildContext context, Widget child) => Padding(
  padding: EdgeInsets.symmetric(horizontal: _isTouch(context) ? 16 : 0),
  child: child,
);

/// Caps a control's width on desktop and fills the column on a phone.
Widget _control(BuildContext context, Widget child) => _isTouch(context)
    ? child
    : Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopControlWidth),
          child: child,
        ),
      );

/// A text input that starts with [text].
class _FilledInput extends StatefulWidget {
  const _FilledInput(this.text, {this.keyboardType});

  final String text;
  final TextInputType? keyboardType;

  @override
  State<_FilledInput> createState() => _FilledInputState();
}

class _FilledInputState extends State<_FilledInput> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CoilInput(controller: _controller, keyboardType: widget.keyboardType);
}

/// A section: a title and its [children], gapped like fields.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = _isTouch(context) ? 16.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: text.title.copyWith(fontWeight: text.emphasis),
          ),
        ),
        SizedBox(height: gap),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          SizedBox(width: double.infinity, child: children[i]),
        ],
      ],
    );
  }
}

/// The action row: the main call to action, and one quieter action.
///
/// Right-aligned on desktop, stacked and full width on a phone.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.accent,
    required this.cta,
    required this.other,
  });

  final bool accent;
  final String cta;
  final String other;

  @override
  Widget build(BuildContext context) {
    final main = CoilButton(
      variant: accent ? CoilButtonVariant.accent : CoilButtonVariant.primary,
      onPressed: () {},
      child: Text(cta),
    );
    final quiet = CoilButton(
      variant: CoilButtonVariant.ghost,
      onPressed: () {},
      child: Text(other),
    );
    if (_isTouch(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [main, quiet],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 8,
      children: [quiet, main],
    );
  }
}

/// A divider-free gap between sections.
double _sectionGap(BuildContext context) => _isTouch(context) ? 32 : 24;

/// "Notifications & privacy" settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.accent, super.key, this.touches = false});

  /// Whether the main call to action is the accent variant.
  final bool accent;

  /// Whether the text link wears the brand ink, as the touched-up theme does.
  final bool touches;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final gap = _sectionGap(context);
    return _gutter(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: CoilTabs<String>(
              value: 'notifications',
              onChanged: (_) {},
              tabs: const [
                CoilTab(value: 'general', label: Text('General')),
                CoilTab(value: 'notifications', label: Text('Notifications')),
                CoilTab(value: 'billing', label: Text('Billing')),
              ],
            ),
          ),
          SizedBox(height: gap),
          Text('Notifications & privacy', style: text.display),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: text.muted.body,
              children: [
                const TextSpan(
                  text: 'Choose what we email you and how we handle it. ',
                ),
                TextSpan(
                  text: 'Learn how we use your data',
                  style: TextStyle(
                    color: touches ? colors.brandInk : colors.foreground,
                    decoration: touches
                        ? TextDecoration.none
                        : TextDecoration.underline,
                    decorationColor: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          _Section(
            title: 'Email',
            children: [
              CoilField(
                label: const Text('Email digests'),
                description: const Text(
                  'Every Monday morning',
                ),
                orientation: CoilFieldOrientation.horizontal,
                child: CoilSwitch(value: true, onChanged: (_) {}),
              ),
              CoilField(
                label: const Text('Mentions'),
                description: const Text('When someone tags you'),
                orientation: CoilFieldOrientation.horizontal,
                child: CoilSwitch(value: true, onChanged: (_) {}),
              ),
              CoilField(
                label: const Text('Product updates'),
                description: const Text('About once a month'),
                orientation: CoilFieldOrientation.horizontal,
                child: CoilSwitch(value: false, onChanged: (_) {}),
              ),
            ],
          ),
          SizedBox(height: gap),
          _Section(
            title: 'Schedule',
            children: [
              CoilField(
                label: const Text('Digest frequency'),
                child: CoilRadioGroup<String>(
                  value: 'weekly',
                  onChanged: (_) {},
                  options: const [
                    CoilOption(value: 'daily', label: Text('Daily')),
                    CoilOption(value: 'weekly', label: Text('Weekly')),
                    CoilOption(value: 'monthly', label: Text('Monthly')),
                  ],
                ),
              ),
              CoilField(
                label: const Text('Send me notifications for'),
                child: CoilCheckboxGroup<String>(
                  values: const {'replies'},
                  onChanged: (_) {},
                  options: const [
                    CoilOption(value: 'replies', label: Text('Replies')),
                    CoilOption(
                      value: 'reactions',
                      label: Text('Reactions'),
                    ),
                  ],
                ),
              ),
              _control(
                context,
                CoilSlider(
                  value: 22,
                  min: 18,
                  max: 24,
                  divisions: 6,
                  onChanged: (_) {},
                  label: const Text('Quiet hours start'),
                  valueBuilder: (context, value) =>
                      Text('${value.round() - 12}:00 PM'),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          _Section(
            title: 'Account',
            children: [
              CoilField(
                label: const Text('Theme'),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CoilToggleGroup<String>(
                    values: const {'dark'},
                    onChanged: (_) {},
                    options: const [
                      CoilOption(value: 'light', label: Text('Light')),
                      CoilOption(value: 'dark', label: Text('Dark')),
                      CoilOption(value: 'system', label: Text('System')),
                    ],
                  ),
                ),
              ),
              CoilField(
                label: const Text('Work email'),
                description: const Text('Digests are sent here.'),
                child: _control(
                  context,
                  const _FilledInput(
                    'ada@lovelace.dev',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          SizedBox(
            width: double.infinity,
            child: _Actions(
              accent: accent,
              cta: 'Save changes',
              other: 'Cancel',
            ),
          ),
        ],
      ),
    );
  }
}

/// "Upgrade plan" checkout.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({required this.accent, super.key, this.touches = false});

  /// Whether the main call to action is the accent variant.
  final bool accent;

  /// Kept for parity with [SettingsScreen]; the checkout has no text link.
  final bool touches;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final gap = _sectionGap(context);
    const features = [
      'Unlimited projects and collaborators',
      'Version history for 90 days',
      'Priority support, answered within a day',
      'Single sign-on with your identity provider',
    ];
    return _gutter(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Upgrade plan', style: text.display),
          const SizedBox(height: 8),
          Text(
            'Pick a billing period and how many seats you need.',
            style: text.muted.body,
          ),
          SizedBox(height: gap),
          Row(
            spacing: 12,
            children: [
              Text(
                'Pro',
                style: text.title.copyWith(fontWeight: text.emphasis),
              ),
              const CoilBadge(
                color: CoilBadgeColor.brand,
                child: Text('Most popular'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 8,
            children: [
              Text(r'$12', style: text.display),
              Text('per seat / month', style: text.muted.body),
            ],
          ),
          SizedBox(height: gap),
          CoilToggleGroup<String>(
            values: const {'yearly'},
            onChanged: (_) {},
            semanticLabel: 'Billing period',
            options: const [
              CoilOption(value: 'monthly', label: Text('Monthly')),
              CoilOption(value: 'yearly', label: Text('Yearly, save 20%')),
            ],
          ),
          SizedBox(height: gap),
          _Section(
            title: 'What you get',
            children: [
              for (final feature in features)
                Row(
                  spacing: metrics.gap,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        size: metrics.iconSize,
                        color: colors.foreground,
                      ),
                      child: const CatalogIcon(Glyph.check),
                    ),
                    Expanded(child: Text(feature, style: text.body)),
                  ],
                ),
            ],
          ),
          SizedBox(height: gap),
          CoilField(
            label: const Text('Seats'),
            description: const Text('You can add more at any time.'),
            child: _control(
              context,
              const _FilledInput('2', keyboardType: TextInputType.number),
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total today',
                        style: text.body.copyWith(fontWeight: text.emphasis),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2 seats, billed yearly',
                        style: text.muted.caption,
                      ),
                    ],
                  ),
                ),
                Text(
                  r'$288',
                  style: text.title.copyWith(
                    fontWeight: text.emphasis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            width: double.infinity,
            child: _Actions(
              accent: accent,
              cta: 'Upgrade to Pro',
              other: 'Compare plans',
            ),
          ),
        ],
      ),
    );
  }
}
