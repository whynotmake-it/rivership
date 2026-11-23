import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/style.dart';

/// A few lines of Dart, lightly highlighted, with a copy button.
///
/// Comments and punctuation sit back, calls read in the foreground, and
/// numbers and sync tokens, the values a demo changes, take the brand
/// color. Long lines scroll sideways instead of wrapping, so the code keeps
/// its shape on a phone.
class CodeBlock extends StatefulWidget {
  const CodeBlock(this.code, {super.key});

  final String code;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  static const _padY = 12.0;

  final _copy = CoilCopyController();

  static final _tokens = RegExp(
    r'(//.*)|(#\w+|\b\d[\d.]*\b)|(\w+)(?=\()|([()\[\]{},;:]|\.(?=\w))',
  );

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  TextSpan _highlight(CoilColors colors) {
    final code = widget.code;
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _tokens.allMatches(code)) {
      if (match.start > start) {
        spans.add(TextSpan(text: code.substring(start, match.start)));
      }
      final color = match.group(2) != null
          ? colors.brand
          : match.group(3) != null
          ? colors.foreground
          : colors.mutedForeground;
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: color),
        ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: code.substring(start)));
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final style = mono(12.5, height: 1.6, color: colors.mutedForeground);
    // The copy button sits centered on the first line.
    final line = MediaQuery.textScalerOf(context).scale(12.5) * 1.6;
    final button = CoilTheme.metricsOf(
      context,
      size: CoilSize.compact,
    ).controlHeight;
    final top = math.max(0.0, _padY + line / 2 - button / 2);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted,
        shape: RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Room at the end for the copy button over the first line.
            padding: const EdgeInsetsDirectional.fromSTEB(16, _padY, 48, _padY),
            child: Text.rich(_highlight(colors), style: style),
          ),
          PositionedDirectional(
            top: top,
            end: top,
            // Code scrolls sideways under the button, so it sits on the
            // block's own fill.
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.muted,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    CoilTheme.radiiOf(context).item,
                  ),
                ),
              ),
              child: ValueListenableBuilder(
                valueListenable: _copy,
                builder: (context, status, _) => CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  semanticLabel: 'Copy code',
                  onPressed: () => _copy.copy(widget.code, context: context),
                  icon: CoilCopySwitcher(
                    status: status,
                    builder: (context, status) => GlyphIcon(
                      status == CoilCopyStatus.copied
                          ? Glyph.check
                          : Glyph.copy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
