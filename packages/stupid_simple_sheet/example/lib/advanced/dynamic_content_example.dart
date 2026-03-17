import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — floating card with text input and list.
class DynamicContentPreview extends StatelessWidget {
  const DynamicContentPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Stack(
      children: [
        // Keyboard placeholder at bottom
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: t.textTertiary.withValues(alpha: .08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 3,
              children: [
                for (var i = 0; i < 7; i++)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: t.textTertiary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Floating card above keyboard
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 58),
            child: MiniModal(
              width: 120,
              height: 80,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: t.previewLine,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const MiniListLine(widthFraction: 0.7),
                    const MiniListLine(widthFraction: 0.5),
                    const MiniListLine(widthFraction: 0.6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A sheet with dynamically growing content and a text input field.
///
/// Uses [originateAboveBottomViewInset] so the sheet stays above the keyboard.
/// Items are added via the text field and the sheet resizes smoothly to
/// accommodate the new content.
class DynamicContentExample extends StatefulWidget {
  const DynamicContentExample({super.key});

  @override
  State<DynamicContentExample> createState() => _DynamicContentExampleState();
}

class _DynamicContentExampleState extends State<DynamicContentExample> {
  List<String> items = List.generate(
    5,
    (index) => 'Item ${index + 1}',
  );

  late final textController = TextEditingController();
  late final focusNode = FocusNode();

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.all(16),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: CupertinoMotion.smooth().duration,
                  curve: CupertinoMotion.smooth().toCurve,
                  child: Column(
                    children: [
                      CupertinoTextField.borderless(
                        focusNode: focusNode,
                        controller: textController,
                        padding: const EdgeInsets.all(16),
                        autofocus: true,
                        placeholder: 'Type something...',
                        onSubmitted: (_) => _addItem(),
                      ),
                      for (var i = 0; i < items.length; i++)
                        CupertinoListTile(
                          title: Text(items[i]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              color: CupertinoColors.opaqueSeparator.resolveFrom(context),
              height: 1,
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    foregroundColor: CupertinoColors.destructiveRed,
                    child: const Text('Close'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                Expanded(
                  child: CupertinoButton(
                    child: const Text('Add Item'),
                    onPressed: () => _addItem(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    setState(() {
      final text = textController.text.isEmpty
          ? 'Item ${items.length + 1}'
          : textController.text;
      items.add(text);
      textController.clear();
      focusNode.requestFocus();
    });
  }
}
