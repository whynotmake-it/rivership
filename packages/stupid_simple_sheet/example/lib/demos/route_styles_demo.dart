import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// The same share sheet as coil, glass and Cupertino.
class RouteStylesDemo extends StatelessWidget {
  /// Creates the demo.
  const RouteStylesDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      const DemoScaffold(title: Text('Photos'), body: SizedBox.shrink());
}
