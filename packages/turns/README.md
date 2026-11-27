# turns

Turn-anchored scroll primitives and incremental streaming markdown parsing for
Flutter AI chat transcripts, streaming timelines, and messaging feeds.

## Libraries

- `package:turns/turns.dart` — full public API (scroll + markdown).
- `package:turns/scroll.dart` — `TurnScrollView`, `TurnScrollView.sectioned`,
  `CustomTurnScrollView`, `SliverTurnList`, `SliverTurnStage`,
  `TurnScrollController`, `TurnScrollScope`, `TurnScrollItem`.
- `package:turns/markdown.dart` — `MarkdownSession`, `MarkdownDocument`,
  `MarkdownSegment`, `parseMarkdown`, `completeMarkdown`, `markdownBoundary`,
  and pure-Dart LaTeX math inline syntaxes (`latexMathSyntaxes`,
  `DisplayMathSyntax`, `InlineMathSyntax`).
