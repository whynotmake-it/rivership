import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A small floating sheet that sizes to its content and can grow dynamically.
/// Uses [originateAboveBottomViewInset] to stay above the keyboard.
///
/// See also: [StupidSimpleSheetRoute]
void showResizingSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      backgroundSnapshotMode: RouteSnapshotMode.settled,
      motion: CupertinoMotion.smooth(),
      originateAboveBottomViewInset: true,
      child: const ResizingSheetExample(),
    ),
  );
}

class ResizingSheetExample extends StatefulWidget {
  const ResizingSheetExample({super.key});

  @override
  State<ResizingSheetExample> createState() => _ResizingSheetExampleState();
}

class _ResizingSheetExampleState extends State<ResizingSheetExample> {
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
        margin: EdgeInsets.all(16),
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
                        padding: EdgeInsetsGeometry.all(16),
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
                    child: Text('Close'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                Expanded(
                  child: CupertinoButton(
                    child: Text('Add Item'),
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
