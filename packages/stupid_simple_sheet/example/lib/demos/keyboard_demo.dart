import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// A quick-add form that stays above the keyboard.
class KeyboardDemo extends StatelessWidget {
  /// Creates the demo.
  const KeyboardDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      const DemoScaffold(title: Text('Tasks'), body: SizedBox.shrink());
}
