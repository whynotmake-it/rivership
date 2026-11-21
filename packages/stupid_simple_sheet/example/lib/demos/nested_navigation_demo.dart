import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// Filters that push their pages inside one sheet.
class NestedNavigationDemo extends StatelessWidget {
  /// Creates the demo.
  const NestedNavigationDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      const DemoScaffold(title: Text('Shop'), body: SizedBox.shrink());
}
