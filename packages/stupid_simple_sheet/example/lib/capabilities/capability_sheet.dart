import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/code_block.dart';
import 'package:stupid_simple_sheet_example/shell/rows.dart';

/// The inset where a sheet's title, its rows' text and its content all
/// line up (DESIGN 13.3).
const sheetInset = 16.0;

/// How a [CapabilitySheet] holds its content, which is also how tall the
/// sheet gets.
enum CapabilitySheetLayout {
  /// A scroll view that hugs its content: short content makes a short
  /// sheet, and taller content grows it to the top cap and scrolls.
  fitsContent,

  /// A list that fills the sheet up to the top cap.
  fills,

  /// A column that doesn't scroll, for content that scrolls on its own.
  fixed,
}

/// The content of a coil-styled capability sheet: the title, one muted
/// line saying what to try, the demo's own content, and the snippet that
/// opened the sheet.
class CapabilitySheet extends StatelessWidget {
  /// Creates the content of a capability's sheet.
  const CapabilitySheet({
    required this.title,
    required this.hint,
    required this.code,
    super.key,
    this.children = const [],
    this.footer,
    this.close = const CoilSheetCloseButton(),
    this.layout = CapabilitySheetLayout.fitsContent,
  });

  /// The sheet's title, the capability's.
  final String title;

  /// One sentence saying what to try here.
  final String hint;

  /// The snippet that opened this sheet.
  final String code;

  /// The demo's own content, between the hint and the snippet.
  final List<Widget> children;

  /// A pinned footer under the content.
  final Widget? footer;

  /// The header's close button; null for none.
  final Widget? close;

  /// How the content is held, and so how tall the sheet gets.
  final CapabilitySheetLayout layout;

  @override
  Widget build(BuildContext context) {
    final hintLine = Padding(
      padding: const EdgeInsets.symmetric(horizontal: sheetInset),
      child: Text(hint, style: CoilTheme.textOf(context).muted.body),
    );
    final block = Padding(
      padding: const EdgeInsets.symmetric(horizontal: sheetInset),
      child: CodeBlock(code: code),
    );
    final body = <Widget>[
      hintLine,
      const SizedBox(height: 16),
      ...children,
      const SizedBox(height: 16),
      block,
    ];
    const padding = EdgeInsets.only(top: 8, bottom: 12);
    return CoilSheetPanel(
      title: Text(title),
      close: close,
      footer: footer,
      child: switch (layout) {
        CapabilitySheetLayout.fills => ListView(
          padding: padding,
          children: body,
        ),
        CapabilitySheetLayout.fitsContent => SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
        CapabilitySheetLayout.fixed => Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
      },
    );
  }
}

/// Numbered rows, so there is something to move, scroll and measure
/// against. They are rows 1 to [count], or [from] to `from + count - 1`.
List<Widget> capabilityRows(int count, {int from = 1}) => [
  for (var i = from; i < from + count; i++) DemoRow(label: Text('Row $i')),
];
