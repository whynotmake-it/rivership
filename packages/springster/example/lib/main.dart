import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:springster_example/2d_redirection.dart';
import 'package:springster_example/draggable_icons.dart';
import 'package:springster_example/flip-card.dart';
import 'package:springster_example/one_dimension.dart';
import 'package:springster_example/pip.dart';

void main() async {
  runApp(
    CupertinoApp.router(
      routerConfig: router,
    ),
  );
}

final springsterRoutes = [
  GoRoute(
    name: 'one-dimension',
    path: 'one-dimension',
    builder: (context, state) => OneDimensionExample(),
  ),
  GoRoute(
    name: 'two-dimension-redirection',
    path: 'two-dimension-redirection',
    builder: (context, state) => TwoDimensionRedirectionExample(),
  ),
  GoRoute(
    name: 'draggable-icons',
    path: 'draggable-icons',
    builder: (context, state) => DraggableIconsExample(),
  ),
  GoRoute(
    name: 'pip',
    path: 'pip',
    builder: (context, state) => PipExample(),
  ),
  GoRoute(
    name: 'flip-card',
    path: 'flip-card',
    builder: (context, state) => FlipCardExample(),
  ),
];

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => SpringsterExample(),
      routes: springsterRoutes,
    ),
  ],
);

class SpringsterExample extends StatelessWidget {
  const SpringsterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Springster Examples'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  CupertinoButton.filled(
                    onPressed: () => context.goNamed('one-dimension'),
                    child: const Text('One Dimension'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () =>
                        context.goNamed('two-dimension-redirection'),
                    child: const Text('Two Dimension Redirection'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.goNamed('draggable-icons'),
                    child: const Text('Draggable Icons'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.goNamed('pip'),
                    child: const Text('Picture in Picture'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.goNamed('flip-card'),
                    child: const Text('Flip Card'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
