import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

class DraggableIconsPage extends StatefulWidget {
  const DraggableIconsPage({super.key});
  static const routeName = 'Draggable Icons';

  @override
  State<DraggableIconsPage> createState() => _DraggableIconsPageState();
}

class _DraggableIconsPageState extends State<DraggableIconsPage> {
  final List<IconData> _accepted = [];
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: DraggableIconsPage.routeName,
      description:
          'MotionDraggable adds spring-backed drag and drop to any widget. '
          'Drag a chip to the target — release anywhere else and it springs '
          'back home.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(
          onPressed: () => setState(_accepted.clear),
          child: const Text('Reset'),
        ),
      ),
      child: SizedBox(
        height: 320,
        child: Stage(
          label: 'Drag to target',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DragTarget<IconData>(
                onWillAcceptWithDetails: (_) {
                  setState(() => _isHovering = true);
                  return true;
                },
                onLeave: (_) => setState(() => _isHovering = false),
                onAcceptWithDetails: (details) {
                  setState(() {
                    _isHovering = false;
                    _accepted.add(details.data);
                  });
                },
                builder: (context, candidate, rejected) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isHovering ? 92 : 84,
                  height: _isHovering ? 92 : 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isHovering ? t.surfaceSolid : t.surface,
                    border: Border.all(
                      color: _isHovering ? t.borderStrong : t.border,
                      width: _isHovering ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _accepted.isEmpty ? CupertinoIcons.add : _accepted.last,
                      color: _accepted.isEmpty ? t.textTertiary : t.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _DraggableIcon(icon: CupertinoIcons.heart_fill),
                  SizedBox(width: 28),
                  _DraggableIcon(icon: CupertinoIcons.star_fill),
                  SizedBox(width: 28),
                  _DraggableIcon(icon: CupertinoIcons.bookmark_fill),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableIcon extends StatelessWidget {
  const _DraggableIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MotionDraggable<IconData>(
      data: icon,
      motion: const CupertinoMotion.bouncy(),
      onlyReturnWhenCanceled: false,
      feedback: _IconChip(icon: icon, dragging: true),
      child: _IconChip(icon: icon),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.dragging = false});
  final IconData icon;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceSolid,
        border: Border.all(color: dragging ? t.borderStrong : t.border),
        boxShadow: dragging ? t.softShadow : t.hairlineShadow,
      ),
      child: Center(child: Icon(icon, color: t.textPrimary, size: 24)),
    );
  }
}
