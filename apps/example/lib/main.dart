import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:springster_example/main.dart';
import 'package:heroine_example/main.dart';

void main() async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Home(),
      ),
      GoRoute(
        path: '/heroine',
        builder: (context, state) => const HeroineExampleApp(),
      ),
      GoRoute(
        path: '/springster',
        builder: (context, state) => const SpringsterExampleApp(),
      ),
    ],
  );

  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    ),
  );
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('whynotmake.it Examples'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            FilledButton.tonal(
              onPressed: () => context.go('/heroine'),
              child: const Text('Heroine'),
            ),
            FilledButton.tonal(
              onPressed: () => context.go('/springster'),
              child: const Text('Springster'),
            ),
          ],
        ),
      ),
    );
  }
}
