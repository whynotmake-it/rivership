import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:springster_example/2d_redirection.dart';
import 'package:springster_example/draggable_icons.dart';
import 'package:springster_example/flip-card.dart';
import 'package:springster_example/one_dimension.dart';
import 'package:springster_example/pip.dart';
import 'package:flutter/material.dart';

void main() async {
  runApp(SpringsterExampleApp());
}

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => SpringsterExample(),
      routes: [
        GoRoute(
            path: 'one-dimension',
            builder: (context, state) => OneDimensionExample()),
        GoRoute(
          path: 'two-dimension-redirection',
          builder: (context, state) => TwoDimensionRedirectionExample(),
        ),
        GoRoute(
          path: 'draggable-icons',
          builder: (context, state) => DraggableIconsExample(),
        ),
        GoRoute(
          path: 'pip',
          builder: (context, state) => PipExample(),
        ),
        GoRoute(
          path: 'flip-card',
          builder: (context, state) => FlipCardExample(),
        ),
      ],
    ),
  ],
);

class SpringsterExampleApp extends StatelessWidget {
  const SpringsterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      routerConfig: router,
    );
  }
}

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
                    onPressed: () => context.go('/one-dimension'),
                    child: const Text('One Dimension'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.go('/two-dimension-redirection'),
                    child: const Text('Two Dimension Redirection'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.go('/draggable-icons'),
                    child: const Text('Draggable Icons'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.go('/pip'),
                    child: const Text('Picture in Picture'),
                  ),
                  CupertinoButton.filled(
                    onPressed: () => context.go('/flip-card'),
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
