/// @docImport 'package:coil/accordion.dart';
/// @docImport 'package:coil/foundation.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How many items of a [CoilAccordion] can be open at once.
enum CoilAccordionMode {
  /// At most one item open at a time.
  ///
  /// Opening an item closes the currently open one.
  single,

  /// Any number of items open at once.
  multiple,
}

/// Visual layout and hover treatment for a [CoilAccordion].
enum CoilAccordionVariant {
  /// Full-width layout where each trigger shows its own hover fill.
  plain,

  /// Narrow layout with a shared hover highlight across triggers and a tint
  /// behind open items.
  group,
}

/// A single expandable section in a [CoilAccordion].
@immutable
class CoilAccordionItem<T> {
  /// Creates an accordion item.
  const CoilAccordionItem({
    required this.value,
    required this.label,
    required this.panel,
    this.leading,
    this.semanticLabel,
    this.enabled = true,
  });

  /// Identifier reported when this item opens or closes.
  ///
  /// Must be unique within the accordion.
  final T value;

  /// The trigger's label, usually a [Text].
  final Widget label;

  /// Names the open panel for screen readers, usually the label's text.
  final String? semanticLabel;

  /// The panel's content, shown while the item is open.
  final Widget panel;

  /// An optional glyph before the label, styled by [IconTheme].
  final Widget? leading;

  /// Whether the item can be toggled.
  ///
  /// Arrow keys skip disabled items.
  final bool enabled;
}

/// The animated parts of a [CoilAccordion].
///
/// Use these as keys of [CoilAccordion.motions] or
/// [CoilAccordionStyle.motions].
final class CoilAccordionTrack<T extends Object> extends Track<T> {
  CoilAccordionTrack._(super.converter, {required String super.debugLabel});

  /// The chevron's quarter turn.
  ///
  /// Defaults to [CoilMotion.quick] opening and [CoilMotion.quickExit] closing.
  static final chevron = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.chevron',
  );

  /// How open a panel is, from 0 to 1.
  ///
  /// Defaults to [CoilMotion.standard] opening and [CoilMotion.standardExit]
  /// closing.
  static final height = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.height',
  );

  /// A panel's opacity.
  ///
  /// Defaults to [CoilMotion.fade] opening and [CoilMotion.fadeExit] closing.
  static final opacity = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.opacity',
  );

  /// The tint behind an open item of the group variant.
  ///
  /// Defaults to [CoilMotion.fade] showing and [CoilMotion.fadeExit] clearing.
  static final tint = CoilAccordionTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilAccordion.tint',
  );

  /// A trigger's own fill.
  ///
  /// Defaults to [CoilMotion.fade] showing and [CoilMotion.fadeExit] clearing.
  static final fill = CoilAccordionTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilAccordion.fill',
  );

  /// A trigger's label color.
  ///
  /// Defaults to [CoilMotion.fade].
  static final label = CoilAccordionTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilAccordion.label',
  );

  /// A trigger's label weight, from normal to semibold.
  ///
  /// Defaults to [CoilMotion.fade].
  static final weight = CoilAccordionTrack<double>._(
    .single,
    debugLabel: 'CoilAccordion.weight',
  );
}
