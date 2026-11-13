// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// The slider's value text. A hidden semibold copy of each string in
/// [reserve] keeps the slot's width fixed as the weight and the digits
/// change. Screen readers get the value from the slider's node instead.
class SliderValueText extends StatelessWidget {
  const SliderValueText({
    required this.text,
    required this.reserve,
    required this.style,
    required this.color,
    required this.emphasis,
    super.key,
  });

  final String text;
  final Set<String> reserve;
  final TextStyle style;
  final Color color;

  /// 0 regular, 1 semibold.
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final semibold = style.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    return ExcludeSemantics(
      child: Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          for (final r in reserve)
            Opacity(
              opacity: 0,
              child: Text(r, style: semibold, maxLines: 1, softWrap: false),
            ),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: style.copyWith(
              color: color,
              fontVariations: sliderWeight(emphasis),
            ),
          ),
        ],
      ),
    );
  }
}

/// Font variations between regular and semibold, `opsz` following `wght`.
List<FontVariation> sliderWeight(double emphasis) {
  final wght = 400 + (CoilWeight.semibold.wght - 400) * emphasis;
  return [
    FontVariation('wght', wght),
    FontVariation('opsz', 14 + (wght - 400) / 150 * 4),
  ];
}
