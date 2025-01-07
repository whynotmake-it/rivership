import 'package:flutter/material.dart';
import 'package:springster_example/main.dart';
import 'package:superhero/superhero.dart';
import 'package:superhero_example/main.dart';

void main() async {
  runApp(
    MaterialApp(
      color: Colors.blue,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const Home(),
        '/superhero': (context) => const SuperheroExampleApp(),
        '/springster': (context) => const SpringsterExampleApp(),
      },
      navigatorObservers: [SuperheroController()],
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
              onPressed: () => Navigator.pushNamed(context, '/superhero'),
              child: const Text('Superhero'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pushNamed(context, '/springster'),
              child: const Text('Springster'),
            ),
          ],
        ),
      ),
    );
  }
}
