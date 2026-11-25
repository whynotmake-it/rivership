/// Coil's [CoilMarkdown]: GitHub-flavored markdown for reading, built for
/// text that streams in.
///
/// Self-contained so it can become its own package: it uses only Coil's
/// foundation, primitives and button, plus `package:markdown`, which no
/// other part of Coil imports. [CoilMarkdownSession] and [completeMarkdown]
/// are plain Dart and need no widgets.
///
/// @docImport 'package:coil/markdown.dart';
library;

export 'src/components/markdown/markdown.dart';
export 'src/components/markdown/markdown_complete.dart';
export 'src/components/markdown/markdown_session.dart';
export 'src/components/markdown/markdown_style.dart';
