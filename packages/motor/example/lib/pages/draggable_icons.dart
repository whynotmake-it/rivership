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
  final List<IconData> _acceptedIcons = [];
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: DraggableIconsPage.routeName,
      description:
          'MotionDraggable with spring-based return animations. '
          'Drag the icons to the target circle.',
      action: CupertinoButton(
        onPressed: () => setState(() => _acceptedIcons.clear()),
        child: const Text('Reset'),
      ),
      child: SizedBox(
        height: 300,
        child: Stage(
          label: 'DRAG TO TARGET',
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
                    _acceptedIcons.add(details.data);
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isHovering ? 88 : 80,
                    height: _isHovering ? 88 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isHovering
                          ? t.accentBlue.withValues(alpha: .2)
                          : t.surface,
                      border: Border.all(
                        color: _isHovering ? t.accentBlue : t.borderSubtle,
                        width: _isHovering ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: _acceptedIcons.isEmpty
                          ? Icon(
                              CupertinoIcons.plus,
                              color: t.textTertiary,
                              size: 24,
                            )
                          : Icon(
                              _acceptedIcons.last,
                              color: t.accentBlue,
                              size: 28,
                            ),
                    ),
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DraggableIcon(
                    icon: CupertinoIcons.heart_fill,
                    color: t.accentGreen,
                  ),
                  const SizedBox(width: 32),
                  _DraggableIcon(
                    icon: CupertinoIcons.star_fill,
                    color: t.accentPurple,
                  ),
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
  const _DraggableIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MotionDraggable<IconData>(
      data: icon,
      motion: const CupertinoMotion.bouncy(),
      onlyReturnWhenCanceled: false,
      feedback: _IconCircle(icon: icon, color: color, isDragging: true),
      child: _IconCircle(icon: icon, color: color),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.color,
    this.isDragging = false,
  });

  final IconData icon;
  final Color color;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isDragging ? .3 : .15),
        border: Border.all(
          color: color.withValues(alpha: isDragging ? .8 : .4),
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Center(child: Icon(icon, color: color, size: 26)),
    );
  }
}
