import 'package:flutter/material.dart';
import 'package:superhero/superhero.dart';

void main() async {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  runApp(MaterialApp(
    theme: ThemeData.from(
      colorScheme: colorScheme,
    ),
    home: SuperheroExample(),
    navigatorObservers: [SuperheroController()],
  ));
}

class SuperheroExample extends StatelessWidget {
  const SuperheroExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page 1'),
      ),
      body: Center(
        child: Superhero(
          tag: 'hero',
          transitionOnUserGestures: true,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: const Size(200, 200),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Page2()),
              );
            },
            child: const Text('Go to Page 2'),
          ),
        ),
      ),
    );
  }
}

class Page2 extends StatelessWidget {
  const Page2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page 2'),
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: Superhero(
          transitionOnUserGestures: true,
          tag: 'hero',
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              fixedSize: const Size(400, 400),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Go to Page 1'),
          ),
        ),
      ),
    );
  }
}
