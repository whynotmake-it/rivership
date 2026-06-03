import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A navigation drawer in a handful of lines: one [SingleMotionController]
/// drives the panel offset and scrim, and a drag hands its velocity straight
/// to the spring so flicks settle naturally.
class DrawerPage extends StatefulWidget {
  const DrawerPage({super.key});
  static const routeName = 'Drawer';

  @override
  State<DrawerPage> createState() => _DrawerPageState();
}

class _DrawerPageState extends State<DrawerPage> with TickerProviderStateMixin {
  static const _panelWidth = 240.0;
  late final SingleMotionController _open;

  @override
  void initState() {
    super.initState();
    _open = SingleMotionController(
      motion: const CupertinoMotion.snappy(),
      vsync: this,
      initialValue: 0,
    );
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _animateTo(double target, {double velocity = 0}) {
    _open.animateTo(target, withVelocity: velocity / _panelWidth);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _open.value = (_open.value + d.delta.dx / _panelWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    final target = v.abs() > 350
        ? (v > 0 ? 1.0 : 0.0)
        : (_open.value > 0.5 ? 1.0 : 0.0);
    _animateTo(target, velocity: v);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: DrawerPage.routeName,
      description:
          'A spring-driven navigation drawer. Tap the menu to open, then drag '
          'the panel or scrim to dismiss — the release velocity flows straight '
          'into the spring via withVelocity.',
      child: SizedBox(
        height: 420,
        child: Surface(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ExampleTheme.surfaceRadius),
            child: AnimatedBuilder(
              animation: _open,
              builder: (context, _) {
                final v = _open.value.clamp(0.0, 1.0);
                return Stack(
                  children: [
                    _AppScreen(onMenu: () => _animateTo(1)),
                    if (v > 0)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _animateTo(0),
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                          child: ColoredBox(
                            color: t.ink.withValues(alpha: v * .35),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset((v - 1) * _panelWidth, 0),
                      child: GestureDetector(
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: _Panel(width: _panelWidth),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AppScreen extends StatelessWidget {
  const _AppScreen({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ColoredBox(
      color: t.surfaceSolid,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onMenu,
                  child: Icon(CupertinoIcons.line_horizontal_3,
                      color: t.textPrimary, size: 26),
                ),
                const SizedBox(width: 16),
                Text(
                  'Inbox',
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 4; i++) ...[
              _SkeletonRow(emphasis: i == 0),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({this.emphasis = false});
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: t.fog, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: emphasis ? 160 : 120,
                height: 10,
                decoration: BoxDecoration(
                  color: t.fog,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 90,
                height: 8,
                decoration: BoxDecoration(
                  color: t.fog,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.width});
  final double width;

  static const _items = [
    (CupertinoIcons.tray_fill, 'Inbox'),
    (CupertinoIcons.star, 'Starred'),
    (CupertinoIcons.paperplane, 'Sent'),
    (CupertinoIcons.archivebox, 'Archive'),
    (CupertinoIcons.gear, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        border: Border(right: BorderSide(color: t.border)),
        boxShadow: t.softShadow,
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mail',
                style: TextStyle(
                  fontFamily: 'Archivo',
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.4,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              for (final (index, (icon, label)) in _items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: index == 0 ? t.fog : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: t.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
