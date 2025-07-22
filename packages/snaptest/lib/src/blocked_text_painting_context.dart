import 'package:flutter/rendering.dart';

/// {@template blocked_text_painting_context}
/// A painting context used to replace all text blocks with colored rectangles.
///
/// This is used in golden tests to circumvent inconsistencies with font
/// rendering between operating systems.
///
/// Only used internally and should not be used by consumers.
/// {@endtemplate}
class BlockedTextPaintingContext extends PaintingContext {
  /// {@macro blocked_text_painting_context}
  BlockedTextPaintingContext({
    required ContainerLayer containerLayer,
    required Rect estimatedBounds,
  }) : super(containerLayer, estimatedBounds);

  @override
  PaintingContext createChildContext(ContainerLayer childLayer, Rect bounds) {
    return BlockedTextPaintingContext(
      containerLayer: childLayer,
      estimatedBounds: bounds,
    );
  }

  @override
  void paintChild(RenderObject child, Offset offset) {
    if (child is RenderParagraph) {
      final paint = Paint()
        ..color = child.text.style?.color ?? const Color(0xFF000000);
      canvas.drawRect(offset & child.size, paint);
    } else {
      return child.paint(this, offset);
    }
  }

  /// Paints the single given [RenderObject].
  void paintSingleChild(RenderObject child) {
    paintChild(child, Offset.zero);
    stopRecordingIfNeeded();
  }
}
