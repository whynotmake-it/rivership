import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/editor_page.dart';
import 'package:merging_dots_example/font_licenses.dart';

export 'package:merging_dots_example/editor/editor_page.dart'
    show MergingDotsEditor;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // Load the shaders before the first frame, so dots merge right away.
  DotShaders.precache();
  runApp(const MergingDotsApp());
}

/// The editor as a standalone app: a bare [WidgetsApp], since coil needs no
/// Material or Cupertino shell. Without a `CoilTheme`, coil follows the
/// platform's brightness.
class MergingDotsApp extends StatelessWidget {
  const MergingDotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Merging Dots',
      color: CoilColors.light.brand,
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      home: const MergingDotsEditor(),
    );
  }
}
