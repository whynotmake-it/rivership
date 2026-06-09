import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// Consistent page scaffold for every motor demo.
class ExamplePage extends StatelessWidget {
  const ExamplePage({
    required this.title,
    required this.description,
    required this.action,
    required this.child,
    super.key,
  });

  final String title;
  final String description;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(title)),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.list(
                children: [
                  Text(
                    description,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  action,
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded, elevated surface container.
class Surface extends StatelessWidget {
  const Surface({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(ExampleTheme.cardRadius),
        border: Border.all(color: t.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow,
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A stage area with a subtle grid background for interactive demos.
class Stage extends StatelessWidget {
  const Stage({required this.child, this.label, super.key});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Surface(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter(t))),
          Positioned.fill(child: child),
          if (label case final label?)
            Positioned(left: 0, bottom: 0, child: Pill(label)),
        ],
      ),
    );
  }
}

/// A small pill label widget.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.canvas.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// An icon inside a tinted rounded container.
class IconBadge extends StatelessWidget {
  const IconBadge({required this.icon, this.color, super.key});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final c = color ?? t.accentBlue;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(icon, color: c),
      ),
    );
  }
}

/// An uppercase eyebrow label.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: color ?? t.accentGreen,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// A pulsing dot indicator.
class LiveDot extends StatelessWidget {
  const LiveDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const SizedBox.square(dimension: 8),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.theme);

  final ExampleTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.borderSubtle
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => theme != oldDelegate.theme;
}
