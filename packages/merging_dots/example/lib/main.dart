import 'package:flutter/cupertino.dart';
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

class MergingDotsApp extends StatelessWidget {
  const MergingDotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Merging Dots',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: MergingDotsEditor(),
    );
  }
}
