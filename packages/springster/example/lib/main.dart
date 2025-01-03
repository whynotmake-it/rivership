import 'package:example/2d_redirection.dart';
import 'package:example/draggable_icons.dart';
import 'package:example/list.dart';
import 'package:example/one_dimension.dart';
import 'package:example/pip.dart';
import 'package:flutter/material.dart';

void main() async {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  runApp(MaterialApp(
    theme: ThemeData.from(
      colorScheme: colorScheme,
    ),
    home: SpringsterExample(),
  ));
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OneDimensionExample(),
              ),
            ),
            child: const Text('One Dimension'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TwoDimensionRedirectionExample(),
              ),
            ),
            child: const Text('Two Dimension Redirection'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DraggableIconsExample(),
              ),
            ),
            child: const Text('Draggable Icons'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PipExample(),
              ),
            ),
            child: const Text('Picture in Picture'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListExample(),
              ),
            ),
            child: const Text('List'),
          ),
        ],
      ),
    );
  }
}
