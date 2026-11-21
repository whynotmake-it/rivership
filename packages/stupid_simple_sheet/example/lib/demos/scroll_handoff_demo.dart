import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// A long list that hands its drag to the sheet once it reaches the top.
class ScrollHandoffDemo extends StatelessWidget {
  /// Creates the demo.
  const ScrollHandoffDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      const DemoScaffold(title: Text('Library'), body: SizedBox.shrink());
}
