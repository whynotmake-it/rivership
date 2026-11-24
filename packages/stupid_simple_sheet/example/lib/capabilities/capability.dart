import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/capabilities/composition_capabilities.dart';
import 'package:stupid_simple_sheet_example/capabilities/dismissal_capabilities.dart';
import 'package:stupid_simple_sheet_example/capabilities/route_capabilities.dart';
import 'package:stupid_simple_sheet_example/capabilities/scroll_capabilities.dart';
import 'package:stupid_simple_sheet_example/capabilities/size_capabilities.dart';
import 'package:stupid_simple_sheet_example/capabilities/snapping_capabilities.dart';

/// One thing a sheet can do, as a card on the home page and the sheet it
/// opens.
@immutable
class Capability {
  /// Creates a capability.
  const Capability({
    required this.title,
    required this.description,
    required this.code,
    required this.open,
  });

  /// The card's title and the sheet's.
  final String title;

  /// One sentence on the card: what the sheet shows.
  final String description;

  /// The snippet the sheet shows: the code that opened it, down to the
  /// parameters this capability is about.
  final String code;

  /// Opens the sheet. The future completes when it closes.
  final Future<void> Function(BuildContext context) open;
}

/// A section of the home page.
@immutable
class CapabilityGroup {
  /// Creates a group.
  const CapabilityGroup({required this.title, required this.capabilities});

  /// The section heading.
  final String title;

  /// The cards in the section.
  final List<Capability> capabilities;
}

/// Every capability, in the order the home page shows them.
final capabilityGroups = <CapabilityGroup>[
  CapabilityGroup(title: 'Routes', capabilities: routeCapabilities),
  CapabilityGroup(title: 'Snapping', capabilities: snappingCapabilities),
  CapabilityGroup(title: 'Scrolling', capabilities: scrollCapabilities),
  CapabilityGroup(title: 'Size', capabilities: sizeCapabilities),
  CapabilityGroup(title: 'Dismissal', capabilities: dismissalCapabilities),
  CapabilityGroup(title: 'Composition', capabilities: compositionCapabilities),
];
