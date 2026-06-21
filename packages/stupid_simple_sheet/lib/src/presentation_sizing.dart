import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The standard width of an iOS-style form sheet card.
///
/// These metrics approximate iOS `.formSheet` presentations and are
/// intentionally not configurable: a [PresentationSizing] adapts the card to
/// its content and the available space instead of exposing raw dimensions.
const double kFormSheetWidth = 580;

/// The standard height of an iOS-style form sheet card.
const double kFormSheetHeight = 650;

/// The minimum margin on each horizontal side of a form sheet card.
const double kFormSheetMinHorizontalMargin = 40;

/// The minimum margin above and below a form sheet card, in addition to any
/// safe-area insets.
const double kFormSheetMinVerticalMargin = 64;

/// How a presentation is sized along a single axis.
enum _AxisSizing {
  /// Always use the standard size for the presentation, clipping or scrolling
  /// content that does not fit. Mirrors a default iOS form sheet.
  standard,

  /// Shrink to fit the content, never exceeding the standard size.
  fit,

  /// Grow to fit the content, never shrinking below the standard size.
  sticky,
}

/// Describes how a presented sheet should be sized on screen.
///
/// This mirrors SwiftUI's [`PresentationSizing`][1] API: pick a base style
/// ([page], [form], or [automatic]) and optionally refine how it sizes itself
/// to its content per-axis with [fitted] and [sticky].
///
/// ```dart
/// // A centered card on iPad, an edge-to-edge sheet on iPhone (the default):
/// PresentationSizing.form
///
/// // Always an edge-to-edge bottom sheet, regardless of screen width:
/// PresentationSizing.page
///
/// // A form sheet that hugs its content's height:
/// PresentationSizing.form.fitted(vertical: true)
///
/// // A form sheet that grows past the standard width for wide content:
/// PresentationSizing.form.sticky(horizontal: true)
/// ```
///
/// Unlike SwiftUI there is no bare `.fitted` constant (Dart cannot share the
/// `fitted` name between a constant and a method); compose it from a base
/// style instead, e.g. `PresentationSizing.form.fitted()`.
///
/// [1]: https://developer.apple.com/documentation/swiftui/presentationsizing
@immutable
class PresentationSizing {
  const PresentationSizing._({
    required bool isFormStyle,
    required _AxisSizing horizontal,
    required _AxisSizing vertical,
  })  : _isFormStyle = isFormStyle,
        _horizontal = horizontal,
        _vertical = vertical;

  /// The system default sizing.
  ///
  /// For sheets this resolves to [form]: a centered card on regular-width
  /// displays and an edge-to-edge sheet on compact-width displays.
  static const PresentationSizing automatic = form;

  /// An edge-to-edge sheet anchored to the bottom of the screen, regardless of
  /// the screen width. This is the classic iOS "page sheet".
  static const PresentationSizing page = PresentationSizing._(
    isFormStyle: false,
    horizontal: _AxisSizing.standard,
    vertical: _AxisSizing.standard,
  );

  /// An iOS-style form sheet.
  ///
  /// Presents as a centered card on regular-width displays (such as iPad) and
  /// falls back to an edge-to-edge [page] sheet on compact-width displays
  /// (such as iPhone), matching SwiftUI's `.form`.
  static const PresentationSizing form = PresentationSizing._(
    isFormStyle: true,
    horizontal: _AxisSizing.standard,
    vertical: _AxisSizing.standard,
  );

  final bool _isFormStyle;
  final _AxisSizing _horizontal;
  final _AxisSizing _vertical;

  /// Returns a copy of this sizing that shrinks to fit its content in the
  /// given axes, never exceeding the standard size.
  ///
  /// Mirrors SwiftUI's `fitted(horizontal:vertical:)`.
  PresentationSizing fitted({bool horizontal = true, bool vertical = true}) {
    return PresentationSizing._(
      isFormStyle: _isFormStyle,
      horizontal: horizontal ? _AxisSizing.fit : _horizontal,
      vertical: vertical ? _AxisSizing.fit : _vertical,
    );
  }

  /// Returns a copy of this sizing that grows to fit its content in the given
  /// axes, never shrinking below the standard size.
  ///
  /// Mirrors SwiftUI's `sticky(horizontal:vertical:)`.
  PresentationSizing sticky({bool horizontal = true, bool vertical = true}) {
    return PresentationSizing._(
      isFormStyle: _isFormStyle,
      horizontal: horizontal ? _AxisSizing.sticky : _horizontal,
      vertical: vertical ? _AxisSizing.sticky : _vertical,
    );
  }

  /// Whether this sizing should present as a centered form sheet card given
  /// the [screenSize].
  ///
  /// Form-style sizings only present as a card when the screen is wide enough
  /// to fit the standard card width plus its minimum horizontal margins
  /// (a regular-width environment). Otherwise the sheet falls back to an
  /// edge-to-edge [page] presentation.
  bool resolvesToFormSheet(Size screenSize) {
    if (!_isFormStyle) return false;
    return screenSize.width >=
        kFormSheetWidth + 2 * kFormSheetMinHorizontalMargin;
  }

  /// The constraints to apply to the form sheet card, given the [availableSize]
  /// remaining after margins and insets have been removed.
  ///
  /// Only meaningful when [resolvesToFormSheet] is true.
  BoxConstraints formSheetConstraints(Size availableSize) {
    final (minWidth, maxWidth) = _axisConstraints(
      _horizontal,
      standard: kFormSheetWidth,
      available: availableSize.width,
    );
    final (minHeight, maxHeight) = _axisConstraints(
      _vertical,
      standard: kFormSheetHeight,
      available: availableSize.height,
    );
    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
    );
  }

  static (double min, double max) _axisConstraints(
    _AxisSizing sizing, {
    required double standard,
    required double available,
  }) {
    final cappedStandard = math.min(standard, math.max<double>(0, available));
    return switch (sizing) {
      // Fixed at the standard size (clamped to what fits).
      _AxisSizing.standard => (cappedStandard, cappedStandard),
      // Hug the content, never larger than the standard size.
      _AxisSizing.fit => (0, cappedStandard),
      // Start at the standard size and grow with the content.
      _AxisSizing.sticky => (
          cappedStandard,
          math.max(cappedStandard, available),
        ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PresentationSizing &&
      other._isFormStyle == _isFormStyle &&
      other._horizontal == _horizontal &&
      other._vertical == _vertical;

  @override
  int get hashCode => Object.hash(_isFormStyle, _horizontal, _vertical);

  @override
  String toString() => 'PresentationSizing('
      '${_isFormStyle ? 'form' : 'page'}, '
      'horizontal: ${_horizontal.name}, vertical: ${_vertical.name})';
}
