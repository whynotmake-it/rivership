/// Reads a coil package's components the way `dart run coil_cli:eject`
/// does: each component's folder, its public libraries and the names they
/// export. For tools that work with coil's sources, like its docs
/// generator.
library;

export 'src/coil_source.dart' show CoilComponent, CoilSource, EjectException;
