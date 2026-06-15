import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// Consistent page scaffold for every motor demo.
class ExamplePage extends StatelessWidget {
  const ExamplePage({
    required this.title,
    required this.description,
    required this.child,
    this.action,
    this.glow = true,
    super.key,
  });

  final String title;
  final String description;
  final Widget? action;
  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: Stack(
        children: [
          if (glow)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 320,
              child: AmbientGlow(opacity: .18, alignment: Alignment.topCenter),
            ),
          CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                backgroundColor: t.canvas.withValues(alpha: 0),
                border: null,
                largeTitle: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.8,
                    color: t.textPrimary,
                  ),
                ),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        description,
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                      if (action case final action?) ...[
                        const SizedBox(height: 20),
                        action,
                      ],
                      const SizedBox(height: 20),
                      child,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A rounded, single-shadow surface container.
class Surface extends StatelessWidget {
  const Surface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = ExampleTheme.surfaceRadius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A calm staging area for interactive demos — a soft inset with an optional
/// label and a faint ambient glow.
class Stage extends StatelessWidget {
  const Stage({
    required this.child,
    this.label,
    this.glow = true,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final String? label;
  final bool glow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.fog,
        borderRadius: BorderRadius.circular(ExampleTheme.surfaceRadius),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ExampleTheme.surfaceRadius),
        child: Stack(
          children: [
            if (glow)
              const Positioned(
                bottom: -40,
                left: 0,
                right: 0,
                height: 200,
                child: AmbientGlow(
                  opacity: .14,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            Padding(padding: padding, child: child),
            if (label case final label?)
              Positioned(left: 12, bottom: 12, child: Pill(label)),
          ],
        ),
      ),
    );
  }
}

/// A small, quiet pill label.
class Pill extends StatelessWidget {
  const Pill(this.text, {this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GhostPill(text, icon: icon);
}
