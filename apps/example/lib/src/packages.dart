import 'package:flutter/foundation.dart';

/// One package of the rivership repository, as the landing page lists it.
@immutable
class Package {
  /// Creates a package.
  const Package({
    required this.name,
    required this.description,
    this.onPub = false,
    this.exampleRoute,
  });

  /// The package's name, as on pub.dev and in the `packages/` directory.
  final String name;

  /// What the package is, from its pubspec.
  final String description;

  /// Whether the package is published on pub.dev.
  final bool onPub;

  /// The path of the example that runs in this app, if there is one.
  final String? exampleRoute;

  /// The package's page on pub.dev.
  Uri get pubUri => Uri.parse('https://pub.dev/packages/$name');

  /// The package's source on GitHub.
  Uri get githubUri => Uri.parse(
        'https://github.com/whynotmake-it/rivership/tree/main/packages/$name',
      );
}

/// The packages whose examples run in this app, in the order they show.
const examplePackages = [
  Package(
    name: 'coil',
    description:
        'A Flutter design system built on Motor springs, inspired by Fluid '
        'Functionalism. Works under any WidgetsApp.',
    exampleRoute: '/coil',
  ),
  Package(
    name: 'motor',
    description:
        'A unified motion system for Flutter – physics-based springs and '
        'duration-based curves under one API.',
    onPub: true,
    exampleRoute: '/motor',
  ),
  Package(
    name: 'heroine',
    description: "The queen of hero transitions. Flutter's most addictive "
        'interactions.',
    onPub: true,
    exampleRoute: '/heroine',
  ),
  Package(
    name: 'stupid_simple_sheet',
    description: 'A simple sheet widget for Flutter.',
    onPub: true,
    exampleRoute: '/stupid_simple_sheet',
  ),
];

/// The packages that only link out, in the order they show.
const morePackages = [
  Package(
    name: 'motor_widgets',
    description:
        "Spring-driven versions of Flutter's implicit animation widgets, "
        'built on Motor. Retargeting keeps velocity instead of restarting.',
  ),
  Package(
    name: 'motor_devtools',
    description:
        'Lightweight in-app inspection and motion tuning tools for Motor.',
  ),
  Package(
    name: 'coil_cli',
    description:
        "Ejects coil components into a Flutter app, merges coil's later "
        'changes into the copies, and checks their interaction patterns in '
        'tests.',
  ),
  Package(
    name: 'snaptest',
    description: 'Snap photos in your widget tests.',
    onPub: true,
  ),
  Package(
    name: 'scroll_drag_detector',
    description:
        'A drag gesture detector that can deal with scroll views inside of '
        'it.',
    onPub: true,
  ),
  Package(
    name: 'fixed_ticker',
    description:
        'A drop-in Ticker replacement that uses Timer.periodic to gate '
        'frame callbacks at a fixed interval.',
    onPub: true,
  ),
  Package(
    name: 'rivership',
    description:
        'An opinionated infrastructure package for use with hooks_riverpod.',
    onPub: true,
  ),
  Package(
    name: 'rivership_test',
    description:
        'A package containing testing utilities to accompany the rivership '
        'package.',
    onPub: true,
  ),
];
