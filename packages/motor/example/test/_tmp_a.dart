import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/chapters.dart';
import 'package:snaptest/snaptest.dart';
void main(){
  for (final (t,w,h) in [('Implicit widgets',1280,800),('Implicit widgets',390,1000),('Spring lab',390,1100),('Controllers',1000,700)]) {
  testWidgets('x $t $w', (tester) async {
    tester.view..physicalSize=Size(w.toDouble(),h.toDouble())..devicePixelRatio=1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(home: chapterNamed(t).page()));
    await tester.pump(const Duration(seconds:1));
    await snap();
  });}
}
