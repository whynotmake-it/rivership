import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';

/// A centered header section inspired by the "Sheet Recipes" design.
///
/// Displays either a custom [logo] widget or an [icon] in a bordered
/// rounded-square, followed by a title, a subtitle, and a mono-spaced hint.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.hint,
    this.icon,
    this.iconColor,
    this.logo,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? hint;
  final IconData? icon;
  final Color? iconColor;

  /// An arbitrary widget displayed in the icon badge position.
  /// When set, [icon] and [iconColor] are ignored.
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final hasVisual = logo != null || icon != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasVisual) ...[
            Transform.rotate(
              angle: 0.05,
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.pillBorder),
                  boxShadow: [
                    BoxShadow(
                      color: t.pillShadow,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: logo ??
                    Icon(
                      icon,
                      size: 24,
                      color: iconColor ?? t.accentGold,
                    ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: t.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: t.textPrimary,
              ),
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: t.textSecondary,
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const ['monospace', 'Menlo'],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
