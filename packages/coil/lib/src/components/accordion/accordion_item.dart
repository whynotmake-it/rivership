import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How many items of a `CoilAccordion` can be open at once.
enum CoilAccordionMode {
  /// At most one. Opening an item closes the open one.
  single,

  /// Any number.
  multiple,
}

/// How a `CoilAccordion` looks.
enum CoilAccordionVariant {
  /// Full width. Each trigger shows its own hover fill.
  plain,

  /// Narrow, with one hover highlight shared by the triggers and a tint
  /// behind open items.
  group,
}

/// One section of a `CoilAccordion`.
@immutable
class CoilAccordionItem<T> {
  /// Creates an item.
  const CoilAccordionItem({
    required this.value,
    required this.label,
    required this.panel,
    this.leading,
    this.semanticLabel,
    this.enabled = true,
  });

  /// What the accordion reports when this item opens or closes. It also
  /// identifies the item, so it must be unique within the accordion.
  final T value;

  /// The trigger's label, usually a [Text].
  final Widget label;

  /// Names the open panel for screen readers, usually the label's text.
  final String? semanticLabel;

  /// The panel's content, shown while the item is open.
  final Widget panel;

  /// An optional glyph before the label, styled by [IconTheme].
  final Widget? leading;

  /// Whether the item can be toggled. Arrow keys skip disabled items.
  final bool enabled;
}

/// The animated parts of a `CoilAccordion`. Use them as keys of
/// `CoilAccordion.motions` or `CoilThemeData.trackMotions`.
final class CoilAccordionTrack<T extends Object> extends Track<T> {
  CoilAccordionTrack._(super.converter, {required String super.debugLabel});

  /// The chevron's quarter turn. Default motion: `quick` opening,
  /// `quickExit` closing.
  static final chevron = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.chevron',
  );

  /// How open a panel is, 0 to 1. Default motion: `standard` opening,
  /// `standardExit` closing.
  static final height = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.height',
  );

  /// A panel's opacity. Default motion: `fade` opening, `fadeExit`
  /// closing.
  static final opacity = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.opacity',
  );

  /// The tint behind an open item of the group variant. Default motion:
  /// `fade` showing, `fadeExit` clearing.
  static final tint = CoilAccordionTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilAccordion.tint',
  );

  /// A trigger's own fill. Default motion: `fade` showing, `fadeExit`
  /// clearing.
  static final fill = CoilAccordionTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilAccordion.fill',
  );

  /// A trigger's label color. Default motion: `fade`.
  static final label = CoilAccordionTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilAccordion.label',
  );

  /// A trigger's label weight, normal to semibold. Default motion: `fade`.
  static final weight = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.weight',
  );
}
