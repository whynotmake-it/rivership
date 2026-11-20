/// The coil sidebar: `CoilSidebarScaffold`, `CoilSidebar` and its parts.
library;

export 'src/components/sidebar/sidebar_callouts.dart';
export 'src/components/sidebar/sidebar_controller.dart'
    hide attachSidebarScaffold;
export 'src/components/sidebar/sidebar_menu.dart';
export 'src/components/sidebar/sidebar_panel.dart' hide coilSidebarRowHeight;
export 'src/components/sidebar/sidebar_rail.dart';
export 'src/components/sidebar/sidebar_scaffold.dart';
export 'src/components/sidebar/sidebar_scope.dart'
    show
        CoilSidebarCollapsible,
        CoilSidebarPeek,
        CoilSidebarSide,
        CoilSidebarVariant;
export 'src/components/sidebar/sidebar_style.dart';
export 'src/components/sidebar/sidebar_trigger.dart';
