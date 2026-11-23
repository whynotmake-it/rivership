import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// The playground: every option in one place, the sheet it opens and the
/// code for it.
class PlaygroundPage extends StatelessWidget {
  /// Creates the playground.
  const PlaygroundPage({super.key});

  @override
  Widget build(BuildContext context) => const DemoScaffold(
    title: Text('Playground'),
    body: SizedBox.shrink(),
  );
}
