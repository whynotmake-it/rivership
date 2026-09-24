import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

  /// The code this chapter is about. Pages update it as you interact, so it
  /// shows the call that's running.
  final ValueListenable<String>? code;

  /// Shown under the code, usually a [LiveTimeline].
  final Widget? below;

  final double stageHeight;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final next = chapter.next;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      child: DefaultTextStyle(
        style: p.body,
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
                    const SizedBox(height: 36),
                    Text(chapter.title, style: p.display),
                    const SizedBox(height: 12),
                    Text(lead),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: stageHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.inset,
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(color: p.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: stage,
                        ),
                      ),
                    ),
                    if (code case final code?) ...[
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: code,
                        builder: (context, code, _) => CodeLine(code),
                      ),
                    ],
                    if (below case final below?) ...[
                      const SizedBox(height: 12),
                      below,
                    ],
                    if (next != null) ...[
                      const SizedBox(height: 40),
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
    final p = Palette.of(context);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          PressScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              height: 32,
              padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.chevron_back, size: 15, color: p.text),
                  const SizedBox(width: 4),
                  Text(
                    'All examples',
                    style: archivo(13, weight: 500, color: p.text),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          for (final other in chapters)
            Container(
              width: 14,
              height: 3,
              margin: const EdgeInsets.only(left: 3),
              color: identical(other, chapter) ? p.accent : p.control,
            ),
        ],
      ),
    );
  }
}

/// A few lines of code, lightly highlighted.
class CodeLine extends StatelessWidget {
  const CodeLine(this.code, {super.key});

  final String code;

  static final _tokens = RegExp(
    r'(//.*)|(#\w+|\b\d[\d.]*\b)|(\w+)(?=\()|([()\[\]{},;:]|\.(?=\w))',
  );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _tokens.allMatches(code)) {
      if (match.start > start) {
        spans.add(TextSpan(text: code.substring(start, match.start)));
      }
      final color = match.group(2) != null
          ? p.accent
          : match.group(3) != null
          ? p.text
          : p.textTertiary;
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: color),
        ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: code.substring(start)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border),
      ),
      child: Text.rich(TextSpan(children: spans), style: p.code),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.next});

  final Chapter next;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PressScale(
      // Replace, so walking the chapters doesn't stack pages and back always
      // returns home.
      onTap: () => context.replaceRoute(NamedRoute(next.title)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: p.borderStrong),
        ),
        child: Row(
          children: [
            Text('Next', style: p.body),
            const SizedBox(width: 10),
            Text(next.title, style: p.title),
            const Spacer(),
            Icon(CupertinoIcons.arrow_right, color: p.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
