/// Public entrypoint for mounting the turns example gallery inside another app.
library;

export 'package:turns_example/main.dart' show turnsRoutes, turnsRoutesFor;
export 'package:turns_example/src/shell/turns_shell.dart'
    show
        TurnsShell,
        turnsAiRouteName,
        turnsIMessageRouteName,
        turnsOverviewRouteName,
        turnsShellRouteName,
        turnsSlackRouteName,
        turnsWhatsAppRouteName;
