/// Reads a Coil package's components the same way `dart run coil_cli:eject`
/// does.
///
/// Exposes [CoilSource] and [CoilComponent] for tools that inspect Coil's
/// component folders, public libraries, and exported symbols (such as
/// documentation generators).
///
/// @docImport 'src/coil_source.dart';
library;

export 'src/coil_source.dart' show CoilComponent, CoilSource, EjectException;
