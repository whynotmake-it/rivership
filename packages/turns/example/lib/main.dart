import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:turns_example/src/concepts/jumps_concept.dart';
import 'package:turns_example/src/concepts/pagination_concept.dart';
import 'package:turns_example/src/concepts/pinning_concept.dart';
import 'package:turns_example/src/concepts/prepend_concept.dart';
import 'package:turns_example/src/concepts/streaming_concept.dart';
import 'package:turns_example/src/demos/ai_assistant_demo.dart';
import 'package:turns_example/src/demos/imessage_demo.dart';
import 'package:turns_example/src/demos/onboarding_demo.dart';
import 'package:turns_example/src/demos/slack_demo.dart';
import 'package:turns_example/src/demos/whatsapp_demo.dart';
import 'package:turns_example/src/shell/turns_overview_page.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// Runs the turns example gallery on its own as a pure [WidgetsApp].
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    WidgetsApp.router(
      title: 'turns',
      color: CoilColors.light.brand,
      debugShowCheckedModeBanner: false,
      routerConfig: router.config(),
    ),
  );
}

/// Instant in-place page swap for sidebar-driven navigation.
final _pageRouteType = RouteType.custom(
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      Offstage(
        offstage: animation.status == AnimationStatus.reverse,
        child: child,
      ),
);

/// The gallery's routes for mounting inside another app:
///
/// ```dart
/// NamedRouteDef.shell(
///   name: 'Turns',
///   path: '/turns',
///   children: turnsRoutesFor(onHome: () => router.navigate(home)),
/// )
/// ```
///
/// With [onHome], the brand header at the top of the sidebar navigates back
/// to the host app; without it, the header stays inert.
List<AutoRoute> turnsRoutesFor({VoidCallback? onHome}) => [
  NamedRouteDef(
    name: turnsShellRouteName,
    path: '',
    type: _pageRouteType,
    builder: (context, state) => TurnsShell(onHome: onHome),
    children: [
      NamedRouteDef(
        name: turnsAiRouteName,
        path: '',
        type: _pageRouteType,
        builder: (context, state) => const AiAssistantDemo(),
      ),
      NamedRouteDef(
        name: turnsWhatsAppRouteName,
        path: 'whatsapp',
        type: _pageRouteType,
        builder: (context, state) => const WhatsAppDemo(),
      ),
      NamedRouteDef(
        name: turnsSlackRouteName,
        path: 'slack',
        type: _pageRouteType,
        builder: (context, state) => const SlackDemo(),
      ),
      NamedRouteDef(
        name: turnsIMessageRouteName,
        path: 'imessage',
        type: _pageRouteType,
        builder: (context, state) => const IMessageDemo(),
      ),
      NamedRouteDef(
        name: turnsOnboardingRouteName,
        path: 'onboarding',
        type: _pageRouteType,
        builder: (context, state) => const OnboardingDemo(),
      ),
      for (final (concept, page) in <(TurnsDemoEntry, Widget Function())>[
        (turnsConcepts[0], PinningConcept.new),
        (turnsConcepts[1], PrependConcept.new),
        (turnsConcepts[2], PaginationConcept.new),
        (turnsConcepts[3], JumpsConcept.new),
        (turnsConcepts[4], StreamingConcept.new),
      ])
        NamedRouteDef(
          name: concept.routeName,
          path: concept.path,
          type: _pageRouteType,
          builder: (context, state) => page(),
        ),
      NamedRouteDef(
        name: turnsOverviewRouteName,
        path: 'overview',
        type: _pageRouteType,
        builder: (context, state) => const TurnsOverviewPage(),
      ),
    ],
  ),
];

/// The gallery's routes with an inert brand header. See [turnsRoutesFor].
final turnsRoutes = turnsRoutesFor();

/// The standalone router for `packages/turns/example`.
final router = RootStackRouter.build(
  routes: [NamedRouteDef.shell(name: 'Home', path: '/', children: turnsRoutes)],
);
