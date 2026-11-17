/// Liquid glass for coil: the far end of coil's material scale.
///
/// Glass belongs to the floating control layer (bars, toolbars, menus,
/// sheets, a few floating actions), never to content. Group the chrome that
/// floats together in one `CoilGlassLayer`, one backdrop pass, and melt
/// neighbors with a `CoilGlassGroup`. See README.md.
library;

export 'src/glass.dart';
export 'src/glass_scope.dart';
export 'src/glass_style.dart';
export 'src/glass_tab_bar.dart';
export 'src/on_glass.dart';
