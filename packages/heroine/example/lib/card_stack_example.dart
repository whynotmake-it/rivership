import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';

const _cardColors = [
  Colors.cyan,
  Colors.orange,
  Colors.yellow,
  Colors.green,
  Colors.blue,
  Colors.indigo,
];

class CardStackExample extends StatelessWidget {
  const CardStackExample({super.key});

  static const name = 'Card Stack';
  static const path = 'card-stack';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: Text('Card Stack'),
      ),
      child: Center(
        child: GestureDetector(
          onTap: () {
            context.navigateTo(const NamedRoute(CardGridPage.name));
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < _cardColors.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    top: i * 8.0,
                    left: i * 4.0,
                  ),
                  child: _CardGridItem(
                    index: i,
                    color: _cardColors[i],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardGridPage extends StatelessWidget {
  const CardGridPage({super.key});

  static const name = 'Card Grid';
  static const path = 'card-stack/grid';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        previousPageTitle: 'Stack',
        middle: Text('Grid'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16) +
              EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var i = 0; i < _cardColors.length; i ++)
                _CardGridItem(
                  index: i,
                  color: _cardColors[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardGridItem extends StatelessWidget {
  const _CardGridItem({
    required this.index,
    required this.color,
  });

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      width: 200,
      child: Heroine(
        flightShuttleBuilder: SingleShuttleBuilder(),
        tag: 'card_$index',
        animateOnUserGestures: true,
        zIndex: index,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
