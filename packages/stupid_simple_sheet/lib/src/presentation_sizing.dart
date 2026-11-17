import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// The standard width of an iOS-style form sheet card.
///
/// These metrics approximate SwiftUI's `.form` presentation and are
/// intentionally not configurable: [PresentationSizing] adapts the card to its
/// content and the available space instead of exposing raw dimensions.
@internal
const double kFormSheetWidth = 580;

/// The standard height of an iOS-style form sheet card.
@internal
const double kFormSheetHeight = 650;

/// The minimum margin on each horizontal side of a form sheet card.
@internal
const double kFormSheetMinHorizontalMargin = 40;

/// The minimum margin above and below a form sheet card, in addition to any
/// safe-area insets.
@internal
const double kFormSheetMinVerticalMargin = 64;

/// Additional breathing room below a form sheet card.
@internal
const double kFormSheetBottomInset = 12;

/// The amount a second form sheet is offset above the sheet behind it.
@internal
const double kFormSheetPaddingToPrevious = 20;

/// The shortest side at which an environment is treated like a regular-width
/// presentation.
@internal
const double kRegularPresentationMinShortestSide = 640;

/// How a presentation is sized along a single axis.
enum _AxisSizing {
  /// Always use the standard size, clipping or scrolling content that does not
  /// fit.
  standard,

  /// Shrink to fit the content, never exceeding the standard size.
  fitted,

  /// Grow to fit the content, never shrinking below the standard size.
  sticky,
}

/// Describes how a presented sheet should be sized on screen.
///
/// This mirrors SwiftUI's
/// [`PresentationSizing`](https://developer.apple.com/documentation/swiftui/presentationsizing)
/// API: pick a base style ([page], [form], or [automatic]) and refine how it
/// sizes itself to its content per axis with [fitted] and [sticky].
///
/// ```dart
/// // A centered card on iPad, an edge-to-edge sheet on iPhone (the default):
/// PresentationSizing.form
///
/// // Always an edge-to-edge bottom sheet, regardless of screen size:
/// PresentationSizing.page
///
/// // A form sheet that hugs its content's height:
/// PresentationSizing.form.fitted(horizontal: false, vertical: true)
///
/// // A form sheet that grows past the standard width for wide content:
/// PresentationSizing.form.sticky(horizontal: true)
/// ```
///
/// Unlike SwiftUI there is no bare `.fitted` constant because Dart cannot share
/// `fitted` between a constant and a method; compose it from a base style, for
/// example `PresentationSizing.form.fitted()`.
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
  /// For sheets this resolves to [form]: a centered card in regular-width
  /// environments and an edge-to-edge sheet in compact-width environments.
  static const PresentationSizing automatic = form;

  /// An edge-to-edge sheet anchored to the bottom of the screen, regardless of
  /// the screen width. This is the classic iOS page sheet.
  static const PresentationSizing page = PresentationSizing._(
    isFormStyle: false,
    horizontal: _AxisSizing.standard,
    vertical: _AxisSizing.standard,
  );

  /// An iOS-style form sheet.
  ///
  /// Presents as a centered card in regular-width environments (such as iPad)
  /// and falls back to an edge-to-edge [page] sheet in compact-width
  /// environments (such as iPhone), matching SwiftUI's `.form`.
  static const PresentationSizing form = PresentationSizing._(
    isFormStyle: true,
    horizontal: _AxisSizing.standard,
    vertical: _AxisSizing.standard,
  );

  final bool _isFormStyle;
  final _AxisSizing _horizontal;
  final _AxisSizing _vertical;

  /// Returns a copy of this sizing that shrinks to fit its content in the given
  /// axes, never exceeding the standard size.
  ///
  /// Mirrors SwiftUI's `fitted(horizontal:vertical:)`. Calling it without
  /// arguments is equivalent to SwiftUI's standalone `.fitted` sizing.
  PresentationSizing fitted({bool horizontal = true, bool vertical = true}) {
    return PresentationSizing._(
      isFormStyle: _isFormStyle,
      horizontal: horizontal ? _AxisSizing.fitted : _horizontal,
      vertical: vertical ? _AxisSizing.fitted : _vertical,
    );
  }

  /// Returns a copy of this sizing that grows to fit its content in the given
  /// axes, never shrinking below the standard size.
  ///
  /// Mirrors SwiftUI's `sticky(horizontal:vertical:)`.
  PresentationSizing sticky({bool horizontal = false, bool vertical = false}) {
    return PresentationSizing._(
      isFormStyle: _isFormStyle,
      horizontal: horizontal ? _AxisSizing.sticky : _horizontal,
      vertical: vertical ? _AxisSizing.sticky : _vertical,
    );
  }

  /// Whether this environment is regular enough for content-adaptive sizing.
  ///
  /// Compact presentations ignore `.fitted` and `.sticky`, matching SwiftUI on
  /// iPhone where they remain edge-to-edge page sheets.
  @internal
  bool isRegularPresentation(Size screenSize) {
    // Size classes do not exist in Flutter. The shortest side is the closest
    // approximation: landscape iPhones remain compact, while iPads retain their
    // form presentation in either orientation.
    return screenSize.shortestSide >= kRegularPresentationMinShortestSide;
  }

  /// Whether this sizing should present as a centered form sheet card given
  /// the [screenSize].
  @internal
  bool resolvesToFormSheet(Size screenSize) {
    return _isFormStyle && isRegularPresentation(screenSize);
  }

  /// Whether either axis derives its size from content in the given
  /// [screenSize].
  @internal
  bool sizesToContent(Size screenSize) {
    final hasAdaptiveAxis = _horizontal != _AxisSizing.standard ||
        _vertical != _AxisSizing.standard;
    if (!hasAdaptiveAxis) return false;
    return _isFormStyle
        ? resolvesToFormSheet(screenSize)
        : isRegularPresentation(screenSize);
  }

  /// The space available to a form sheet after its surrounding margins.
  ///
  /// Safe-area padding is included; transient view insets such as the
  /// keyboard intentionally do not shrink the presentation.
  @internal
  Size formSheetAvailableSize(
    BuildContext context, {
    double additionalTopMargin = 0,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    final safeArea = MediaQuery.paddingOf(context);
    final topMargin =
        safeArea.top + kFormSheetMinVerticalMargin + additionalTopMargin;
    final bottomMargin =
        safeArea.bottom + kFormSheetMinVerticalMargin + kFormSheetBottomInset;
    return Size(
      math.max(0, screenSize.width - 2 * kFormSheetMinHorizontalMargin),
      math.max(0, screenSize.height - topMargin - bottomMargin),
    );
  }

  /// The maximum height a sheet can occupy under this sizing in [context].
  @internal
  double maxPresentationExtent(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    if (!resolvesToFormSheet(screenSize)) return screenSize.height;
    return constraintsFor(
      formSheetAvailableSize(context),
      formSheet: true,
    ).maxHeight;
  }

  /// The constraints to apply to the sheet, given the [availableSize]
  /// remaining after presentation margins have been removed.
  @internal
  BoxConstraints constraintsFor(Size availableSize, {required bool formSheet}) {
    final standardWidth = formSheet ? kFormSheetWidth : availableSize.width;
    final standardHeight = formSheet ? kFormSheetHeight : availableSize.height;

    final (minWidth, maxWidth) = _axisConstraints(
      _horizontal,
      standard: standardWidth,
      available: availableSize.width,
    );
    final (minHeight, maxHeight) = _axisConstraints(
      _vertical,
      standard: standardHeight,
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
      _AxisSizing.fitted => (0, cappedStandard),
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
