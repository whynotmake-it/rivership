import 'package:example_design/src/example_theme.dart';
import 'package:flutter/cupertino.dart';

/// A centered header with an optional logo, a featherweight display title,
/// a subtitle, and a monospaced hint.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.hint,
    this.icon,
    this.logo,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? hint;
  final IconData? icon;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final hasVisual = logo != null || icon != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        children: [
          if (hasVisual) ...[
            logo ?? Icon(icon, size: 28, color: t.textPrimary),
            const SizedBox(height: 22),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Archivo',
              fontSize: 44,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.6,
              height: 1.05,
              color: t.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: t.textSecondary,
              ),
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: t.textTertiary,
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
