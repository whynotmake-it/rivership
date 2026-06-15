import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

class PictureInPicturePage extends StatefulWidget {
  const PictureInPicturePage({super.key});
  static const routeName = 'Picture in Picture';

  @override
  State<PictureInPicturePage> createState() => _PictureInPicturePageState();
}

class _PictureInPicturePageState extends State<PictureInPicturePage> {
  int _currentCorner = 0;
  int? _hoveringCorner;

  static const _cornerLabels = ['Top Left', 'Top Right', 'Bottom Left', 'Bottom Right'];

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: PictureInPicturePage.routeName,
      description:
          'MotionDraggable with corner snapping (PiP behavior). '
          'Drag the card to any corner and it snaps with spring physics.',
      action: Pill('Corner: ${_cornerLabels[_currentCorner]}'),
      child: SizedBox(
        height: 360,
        child: Surface(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              for (int i = 0; i < 4; i++)
                _CornerTarget(
                  corner: i,
                  isActive: _currentCorner == i,
                  isHovering: _hoveringCorner == i,
                  onAccept: () => setState(() => _currentCorner = i),
                  onHover: (hovering) =>
                      setState(() => _hoveringCorner = hovering ? i : null),
                ),
              _PipCard(
                currentCorner: _currentCorner,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerTarget extends StatelessWidget {
  const _CornerTarget({
    required this.corner,
    required this.isActive,
    required this.isHovering,
    required this.onAccept,
    required this.onHover,
  });

  final int corner;
  final bool isActive;
  final bool isHovering;
  final VoidCallback onAccept;
  final void Function(bool hovering) onHover;

  Alignment get _alignment => switch (corner) {
        0 => Alignment.topLeft,
        1 => Alignment.topRight,
        2 => Alignment.bottomLeft,
        _ => Alignment.bottomRight,
      };

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Align(
      alignment: _alignment,
      child: DragTarget<bool>(
        onWillAcceptWithDetails: (_) {
          onHover(true);
          return true;
        },
        onLeave: (_) => onHover(false),
        onAcceptWithDetails: (_) {
          onHover(false);
          onAccept();
        },
        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isHovering ? 80 : 60,
            height: isHovering ? 80 : 60,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive
                  ? t.accentBlue.withValues(alpha: .12)
                  : isHovering
                      ? t.accentGreen.withValues(alpha: .12)
                      : t.canvas.withValues(alpha: .4),
              border: Border.all(
                color: isActive
                    ? t.accentBlue.withValues(alpha: .5)
                    : isHovering
                        ? t.accentGreen.withValues(alpha: .5)
                        : t.borderSubtle.withValues(alpha: .5),
              ),
            ),
            child: Center(
              child: Icon(
                isActive
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: isActive
                    ? t.accentBlue
                    : t.textTertiary,
                size: 18,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PipCard extends StatelessWidget {
  const _PipCard({required this.currentCorner});

  final int currentCorner;

  Alignment get _alignment => switch (currentCorner) {
        0 => Alignment.topLeft,
        1 => Alignment.topRight,
        2 => Alignment.bottomLeft,
        _ => Alignment.bottomRight,
      };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MotionDraggable<bool>(
          data: true,
          motion: const CupertinoMotion.bouncy(),
          feedbackMatchesConstraints: true,
          child: _PipVisual(),
          feedback: _PipVisual(isDragging: true),
        ),
      ),
    );
  }
}

class _PipVisual extends StatelessWidget {
  const _PipVisual({this.isDragging = false});

  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: 140,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A1F5E),
            Color(0xFF1A2540),
          ],
        ),
        border: Border.all(
          color: isDragging
              ? t.accentGreen.withValues(alpha: .6)
              : t.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: isDragging ? .4 : .2),
            blurRadius: isDragging ? 20 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.play_fill,
              color: t.textPrimary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'PiP',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
