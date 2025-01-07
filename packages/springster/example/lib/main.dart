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
    return MaterialApp.router(
      routerConfig: router,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  }
}

class SpringsterExample extends StatelessWidget {
  const SpringsterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Springster Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => context.go('/one-dimension'),
            child: const Text('One Dimension'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/two-dimension-redirection'),
            child: const Text('Two Dimension Redirection'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/draggable-icons'),
            child: const Text('Draggable Icons'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/pip'),
            child: const Text('Picture in Picture'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/flip-card'),
            child: const Text('Flip Card'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
