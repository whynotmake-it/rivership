import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

/// How a presentation is sized along a single axis.
enum _AxisSizing {
  /// Take the standard size of the presentation, whatever the content's size.
  standard,

  /// Shrink to fit the content, never exceeding the standard size.
  fit,
}

/// Describes how a presented sheet sizes itself.
///
/// Mirrors SwiftUI's [`PresentationSizing`][1] and the
/// [`presentationSizing(_:)`][2] modifier: pick a base style and optionally
/// refine per axis whether it sizes itself to its content with [fitted].
///
/// ```dart
/// // Hug the content, up to the full height a sheet can have (the default
/// // for glass sheets):
/// PresentationSizing.automatic
///
/// // Always the full height a sheet can have:
/// PresentationSizing.page
///
/// // The same as automatic, spelled out:
/// PresentationSizing.page.fitted(horizontal: false, vertical: true)
/// ```
///
/// Sheets attached to the bottom edge of the screen always take its full
/// width, so only the vertical axis changes their size, the same as UIKit's
/// edge-attached sheets with `widthFollowsPreferredContentSizeWhenEdgeAttached`
/// left off.
///
/// The sizing also decides when a sheet makes the sheet or page behind it
/// recede (scale back): only a sheet whose top edge comes close to the top of
/// the screen pushes back what is behind it, like a sheet at iOS's `.large`
/// detent. A shorter sheet leaves it in place and only dims it, like a sheet
/// at the `.medium` detent.
///
/// Unlike SwiftUI there is no bare `.fitted` constant, since Dart cannot share
/// the `fitted` name between a constant and a method. Use [automatic], or
/// compose one from a base style, e.g. `PresentationSizing.page.fitted()`.
///
/// [1]: https://developer.apple.com/documentation/swiftui/presentationsizing
/// [2]: https://developer.apple.com/documentation/swiftui/view/presentationsizing(_:)
@immutable
class PresentationSizing {
  const PresentationSizing._({
    required _AxisSizing horizontal,
    required _AxisSizing vertical,
  })  : _horizontal = horizontal,
        _vertical = vertical;

  /// The default sizing for glass sheets.
  ///
  /// Hugs the content vertically, up to the full height a sheet can have.
  /// Content with a finite height, such as a `Column` with
  /// `mainAxisSize: MainAxisSize.min`, gets a sheet exactly as tall as itself.
  /// Content that takes all the height it is given, such as a scroll view, a
  /// `Scaffold` or an `Expanded`, gets a full height sheet, the same as
  /// [page].
  ///
  /// Resolves to `page.fitted(horizontal: false, vertical: true)`, which is
  /// what SwiftUI's `.automatic` resolves to on macOS (based on `.form`
  /// there).
  static const PresentationSizing automatic = PresentationSizing._(
    horizontal: _AxisSizing.standard,
    vertical: _AxisSizing.fit,
  );

  /// The sheet always takes the full height a sheet can have, whatever the
  /// height of its content, which sits at the top of the sheet.
  ///
  /// A page sheet always makes the sheet behind it recede while it opens.
  ///
  /// Mirrors SwiftUI's `.page`.
  static const PresentationSizing page = PresentationSizing._(
    horizontal: _AxisSizing.standard,
    vertical: _AxisSizing.standard,
  );

  final _AxisSizing _horizontal;
  final _AxisSizing _vertical;

  /// Returns a copy of this sizing that shrinks to fit its content in the
  /// given axes, never exceeding the standard size.
  ///
  /// Mirrors SwiftUI's `fitted(horizontal:vertical:)`.
  PresentationSizing fitted({bool horizontal = true, bool vertical = true}) {
    return PresentationSizing._(
      horizontal: horizontal ? _AxisSizing.fit : _horizontal,
      vertical: vertical ? _AxisSizing.fit : _vertical,
    );
  }

  /// Whether the sheet takes its height from its content rather than filling
  /// the height it may have.
  @internal
  bool get sizesHeightToContent => _vertical != _AxisSizing.standard;

  /// Whether the sheet takes its size from its content in either axis.
  ///
  /// The sheet's overlay must not decide its size then.
  @internal
  bool get sizesToContent =>
      sizesHeightToContent || _horizontal != _AxisSizing.standard;

  @override
  bool operator ==(Object other) =>
      other is PresentationSizing &&
      other._horizontal == _horizontal &&
      other._vertical == _vertical;

  @override
  int get hashCode => Object.hash(_horizontal, _vertical);

  @override
  String toString() => 'PresentationSizing('
      'horizontal: ${_horizontal.name}, vertical: ${_vertical.name})';
}
