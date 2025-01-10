import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';
import 'package:springster/springster.dart';

void main() {
  group('SpringDraggable', () {
    const childKey = Key('child');
    const feedbackKey = Key('feedback');

    Widget buildChild() => Container(
          key: childKey,
          width: 100,
          height: 100,
          color: Colors.blue,
        );

    Widget buildFeedback() => Container(
          key: feedbackKey,
          width: 100,
          height: 100,
          color: Colors.red,
        );

    testWidgets('builds with child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SpringDraggable<String>(
            data: 'test',
            child: buildChild(),
          ),
        ),
      );

      spotKey(childKey).existsOnce();
    });

    testWidgets('shows feedback when dragging', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SpringDraggable<String>(
            data: 'test',
            feedback: buildFeedback(),
            child: buildChild(),
          ),
        ),
      );

      final child = spotKey(childKey)..existsOnce();

      final gesture = await tester.startGesture(tester.getCenter(child.finder));

      await gesture.moveBy(const Offset(40, 40));
      await gesture.moveBy(const Offset(40, 40));
      await tester.pump();

      spotKey(feedbackKey).existsOnce();
    });

    testWidgets('shows childWhenDragging when dragging', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SpringDraggable<String>(
            data: 'test',
            childWhenDragging: buildFeedback(),
            feedback: const SizedBox(),
            child: buildChild(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();

      expect(find.byKey(childKey), findsNothing);
      expect(find.byKey(feedbackKey), findsOneWidget);
    });

    testWidgets('calls onDragStarted when drag starts', (tester) async {
      var dragStarted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SpringDraggable<String>(
            data: 'test',
            onDragStarted: () => dragStarted = true,
            child: buildChild(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();

      expect(dragStarted, isTrue);
    });

    testWidgets('calls onDragEnd when drag ends', (tester) async {
      var dragEnded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SpringDraggable<String>(
            data: 'test',
            onDragEnd: (_) => dragEnded = true,
            child: buildChild(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragEnded, isTrue);
    });

    testWidgets('respects axis constraint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SpringDraggable<String>(
            data: 'test',
            axis: Axis.horizontal,
            feedback: buildFeedback(),
            child: buildChild(),
          ),
        ),
      );

      final child = spotKey(childKey)..existsOnce();

      final gesture = await tester.startGesture(tester.getCenter(child.finder));
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();

      final feedback = spotKey(feedbackKey)..existsOnce();

      final feedbackBox = tester.getTopLeft(feedback.finder);

      // Should only move horizontally
      expect(feedbackBox.dx, equals(20));
      expect(feedbackBox.dy, equals(0));
    });

    testWidgets('feedback animates back to original position', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SpringDraggable<String>(
              spring: const SimpleSpring(),
              data: 'test',
              feedback: buildFeedback(),
              child: buildChild(),
            ),
          ),
        ),
      );

      final child = spotKey(childKey)..existsOnce();

      final gesture = await tester.startGesture(tester.getCenter(child.finder));
      await gesture.moveBy(const Offset(50, 50));
      await tester.pump();

      final feedback = spotKey(feedbackKey);

      expect(
        tester.getTopLeft(feedback.finder),
        const Offset(50, 50),
      );
      feedback.snapshotRenderBox();

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      feedback.snapshotRenderBox();

      expect(
        tester.getTopLeft(feedback.finder),
        closeToOffset(const Offset(8.9, 8.9), 0.1),
      );

      await tester.pump(const Duration(milliseconds: 250));
      feedback.snapshotRenderBox();
      expect(
        tester.getTopLeft(feedback.finder),
        closeToOffset(const Offset(0.7, 0.7), 0.1),
      );

      await tester.pumpAndSettle();
      feedback.doesNotExist();
    });
  });
}

Matcher closeToOffset(Offset offset, double delta) => isA<Offset>()
    .having((o) => o.dx, 'dx', closeTo(offset.dx, delta))
    .having((o) => o.dy, 'dy', closeTo(offset.dy, delta));
