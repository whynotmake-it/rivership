import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/style.dart';

/// The layout every chapter shares: a title, one line of explanation, the
/// stage, the one line of code that matters, and an optional timeline.
class ChapterPage extends StatelessWidget {
  const ChapterPage({
    required this.chapter,
    required this.lead,
    required this.stage,
    this.code,
    this.below,
    this.stageHeight = 400,
    super.key,
  });

  final Chapter chapter;

  /// One or two sentences.
  final String lead;

  final Widget stage;

  /// The line of code this chapter is about.
  final String? code;

  /// Shown under the code, usually a [LiveTimeline].
  final Widget? below;

  final double stageHeight;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final next = chapter.next;
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: DefaultTextStyle(
        style: t.body,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(chapter: chapter),
                    const SizedBox(height: 28),
                    Text(chapter.title, style: t.display),
                    const SizedBox(height: 12),
                    Text(lead),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: stageHeight,
                      child: _Stage(child: stage),
                    ),
                    if (code case final code?) ...[
                      const SizedBox(height: 14),
                      CodeLine(code),
                    ],
                    if (below case final below?) ...[
                      const SizedBox(height: 14),
                      below,
                    ],
                    if (next != null) ...[
                      const SizedBox(height: 36),
                      _NextButton(next: next),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Row(
      children: [
        PressScale(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.surfaceSolid,
              shape: BoxShape.circle,
              border: Border.all(color: t.border),
              boxShadow: t.hairlineShadow,
            ),
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 18,
              color: t.textPrimary,
            ),
          ),
        ),
        const Spacer(),
        Text('${chapter.number} / ${chapters.length}', style: t.eyebrow),
        const SizedBox(width: 12),
        for (final other in chapters)
          Container(
            width: identical(other, chapter) ? 16 : 5,
            height: 5,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: identical(other, chapter) ? t.textPrimary : t.pebble,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.fog,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(32), child: child),
    );
  }
}

/// A single line of monospace code.
class CodeLine extends StatelessWidget {
  const CodeLine(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Text(code, style: t.code.copyWith(color: t.textPrimary)),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.next});

  final Chapter next;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return PressScale(
      // Replace, so walking the chapters doesn't stack pages and back always
      // returns home.
      onTap: () => context.replaceRoute(NamedRoute(next.title)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: BoxDecoration(
          color: t.textPrimary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT · ${next.number}',
                  style: t.eyebrow.copyWith(
                    color: t.canvas.withValues(alpha: .6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(next.title, style: t.title.copyWith(color: t.canvas)),
              ],
            ),
            const Spacer(),
            Icon(CupertinoIcons.arrow_right, color: t.canvas, size: 20),
          ],
        ),
      ),
    );
  }
}
