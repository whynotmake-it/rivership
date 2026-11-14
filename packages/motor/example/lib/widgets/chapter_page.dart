import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
// For SelectableText only.
import 'package:flutter/material.dart' show SelectableText;
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/style.dart';

/// The layout every chapter shares: a title, a short lead, the stage, the
/// code that is running, and an optional timeline.
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

  /// What to try and what to notice, in a few short sentences.
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
    // Stages lay out text in a fixed height, so they grow with larger text.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      child: DefaultTextStyle(
        style: p.body,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const .fromLTRB(20, 8, 20, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    _TopBar(chapter: chapter),
                    const SizedBox(height: 36),
                    Text(chapter.title, style: p.display),
                    const SizedBox(height: 12),
                    Text(lead),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: stageHeight * math.max(1, textScale),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.inset,
                          borderRadius: .circular(radius),
                          border: Border.all(color: p.border),
                        ),
                        child: ClipRRect(
                          borderRadius: .circular(radius),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          PressScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const .fromLTRB(6, 0, 12, 0),
              decoration: BoxDecoration(
                borderRadius: .circular(radius),
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
          const SizedBox(width: 12),
          // The dots shrink rather than overflow on narrow screens.
          Expanded(
            child: Align(
              alignment: .centerRight,
              child: FittedBox(
                fit: .scaleDown,
                child: Row(
                  children: [
                    for (final other in chapters)
                      Container(
                        width: 14,
                        height: 3,
                        margin: const .only(left: 3),
                        color: identical(other, chapter) ? p.accent : p.control,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A few lines of code, lightly highlighted, that can be selected and
/// copied.
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
      padding: const .symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: .circular(radius),
        border: Border.all(color: p.border),
      ),
      child: SelectableText.rich(
        TextSpan(children: spans),
        style: p.code,
        // The Cupertino menu needs no Material localizations.
        contextMenuBuilder: (context, state) =>
            CupertinoAdaptiveTextSelectionToolbar.editableText(
              editableTextState: state,
            ),
      ),
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
        padding: const .fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: .circular(radius),
          border: Border.all(color: p.borderStrong),
        ),
        child: Row(
          children: [
            Text('Next', style: p.body),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                next.title,
                maxLines: 1,
                overflow: .ellipsis,
                style: p.title,
              ),
            ),
            Icon(CupertinoIcons.arrow_right, color: p.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
