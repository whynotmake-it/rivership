// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Hidden semibold copies of [reserve]: they give a slot the width of its
/// widest string, so the slot never changes width as the weight and the
/// digits change.
class SliderReserve extends StatelessWidget {
  const SliderReserve({required this.reserve, required this.style, super.key});

  final Set<String> reserve;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final semibold = style.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    return ExcludeSemantics(
      child: Stack(
        children: [
          for (final r in reserve)
            Opacity(
              opacity: 0,
              child: Text(r, style: semibold, maxLines: 1, softWrap: false),
            ),
        ],
      ),
    );
  }
}

/// The slider's value text: [parts] in a row (one value, or two around a
/// dash), over a [SliderReserve] that fixes the slot's width.
///
/// Screen readers get the values from the slider's nodes, so the text parts
/// exclude their semantics; an open value field keeps its own.
class SliderValueText extends StatelessWidget {
  const SliderValueText({
    required this.parts,
    required this.reserve,
    required this.style,
    required this.color,
    required this.emphasis,
    super.key,
  });

  final List<Widget> parts;
  final Set<String> reserve;
  final TextStyle style;
  final Color color;

  /// 0 regular, 1 semibold.
  final double emphasis;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: AlignmentDirectional.centerEnd,
    children: [
      SliderReserve(reserve: reserve, style: style),
      DefaultTextStyle(
        style: style.copyWith(
          color: color,
          fontVariations: sliderWeight(emphasis),
        ),
        maxLines: 1,
        softWrap: false,
        child: Row(mainAxisSize: MainAxisSize.min, children: parts),
      ),
    ],
  );
}

/// One value typed in place of its text: as wide as the widest value
/// ([reserve]), with a hairline under it. Done submits; Esc cancels.
class SliderValueField extends StatelessWidget {
  const SliderValueField({
    required this.controller,
    required this.focusNode,
    required this.reserve,
    required this.reserveStyle,
    required this.style,
    required this.underline,
    required this.signed,
    required this.onSubmit,
    required this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Set<String> reserve;
  final TextStyle reserveStyle;
  final TextStyle style;
  final Color underline;

  /// Whether the keyboard needs a minus sign.
  final bool signed;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      SliderReserve(reserve: reserve, style: reserveStyle),
      Positioned.fill(
        // Its own node: a text field, not part of the slider's value.
        child: Semantics(
          container: true,
          child: CoilTextFieldCore(
            controller: controller,
            focusNode: focusNode,
            style: style,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: signed,
            ),
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => onSubmit(),
            shortcuts: sliderFieldShortcuts,
            actions: {
              SliderCancelEditIntent: CallbackAction<SliderCancelEditIntent>(
                onInvoke: (_) => onCancel(),
              ),
            },
            decorationBuilder: (context, field) => DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: underline)),
              ),
              child: field,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Font variations between regular and semibold, `opsz` following `wght`.
List<FontVariation> sliderWeight(double emphasis) {
  final wght = 400 + (CoilWeight.semibold.wght - 400) * emphasis;
  return [
    FontVariation('wght', wght),
    FontVariation('opsz', 14 + (wght - 400) / 150 * 4),
  ];
}
