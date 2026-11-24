import 'package:flutter/widgets.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/controllers.dart';
import 'package:motor_example/pages/converters.dart';
import 'package:motor_example/pages/devtools.dart';
import 'package:motor_example/pages/drag_and_drop.dart';
import 'package:motor_example/pages/implicit_widgets.dart';
import 'package:motor_example/pages/loops.dart';
import 'package:motor_example/pages/phases.dart';
import 'package:motor_example/pages/retarget.dart';
import 'package:motor_example/pages/scrub.dart';
import 'package:motor_example/pages/spring_lab.dart';
import 'package:motor_example/pages/steps.dart';
import 'package:motor_example/pages/sync.dart';
import 'package:motor_example/pages/tick_rates.dart';
import 'package:motor_example/pages/toggle.dart';
import 'package:motor_example/widgets/icons.dart';

/// The sidebar's sections, in order.
enum ChapterGroup {
  springs('Springs'),
  choreography('Choreography'),
  buildingBlocks('Building blocks'),
  widgets('Widgets'),
  tools('Tools');

  const ChapterGroup(this.title);

  final String title;
}

/// One demo in the gallery.
@immutable
class Chapter {
  const Chapter({
    required this.title,
    required this.path,
    required this.idea,
    required this.page,
    required this.group,
    required this.glyph,
  });

  /// Also the route name.
  final String title;

  final String path;

  /// What the demo shows, in one sentence.
  final String idea;

  final Widget Function() page;

  /// The sidebar section it's listed in.
  final ChapterGroup group;

  /// Its icon in the sidebar and on the overview.
  final Glyph glyph;

  /// The following chapter, if any.
  Chapter? get next {
    final index = chapters.indexOf(this);
    return index + 1 < chapters.length ? chapters[index + 1] : null;
  }
}

/// The gallery, in reading order.
final chapters = [
  Chapter(
    title: 'Spring lab',
    path: 'spring-lab',
    idea: 'Tune a spring and see the curve it draws, then drag and let go.',
    page: SpringLabPage.new,
    group: .springs,
    glyph: Glyph.slidersHorizontal,
  ),
  Chapter(
    title: 'Toggle',
    path: 'toggle',
    idea:
        'One controller animates every part, and a drag hands over its speed.',
    page: TogglePage.new,
    group: .springs,
    glyph: Glyph.hand,
  ),
  Chapter(
    title: 'Retarget',
    path: 'retarget',
    idea: 'Retarget mid-flight without a jump. Springs keep their speed.',
    page: RetargetPage.new,
    group: .springs,
    glyph: Glyph.spline,
  ),
  Chapter(
    title: 'Card stack',
    path: 'card-stack',
    idea: 'Throw a card. It keeps your speed and returns under the stack.',
    page: CardStackPage.new,
    group: .springs,
    glyph: Glyph.squareStack,
  ),
  Chapter(
    title: 'Steps',
    path: 'steps',
    idea: 'Each track runs its own steps, with a different motion per step.',
    page: StepsPage.new,
    group: .choreography,
    glyph: Glyph.listOrdered,
  ),
  Chapter(
    title: 'Sync',
    path: 'sync',
    idea: 'Tracks wait for each other at a sync barrier.',
    page: SyncPage.new,
    group: .choreography,
    glyph: Glyph.layers,
  ),
  Chapter(
    title: 'Loops',
    path: 'loops',
    idea:
        'Repeat a slice of steps, run a finite count, or lock sibling loops '
        'together.',
    page: LoopsPage.new,
    group: .choreography,
    glyph: Glyph.infinity,
  ),
  Chapter(
    title: 'Phases',
    path: 'phases',
    idea: 'Named layouts you can drag between, even while they autoplay.',
    page: PhasesPage.new,
    group: .choreography,
    glyph: Glyph.repeat,
  ),
  Chapter(
    title: 'Scrub',
    path: 'scrub',
    idea: 'Scrub to any moment, then play on from there.',
    page: ScrubPage.new,
    group: .choreography,
    glyph: Glyph.timer,
  ),
  Chapter(
    title: 'Converters',
    path: 'converters',
    idea: 'Offsets, colors and angles, with a spring for every dimension.',
    page: ConvertersPage.new,
    group: .buildingBlocks,
    glyph: Glyph.move,
  ),
  Chapter(
    title: 'Controllers',
    path: 'controllers',
    idea: 'Drive a value from code, interrupt it and read its velocity.',
    page: ControllersPage.new,
    group: .buildingBlocks,
    glyph: Glyph.gauge,
  ),
  Chapter(
    title: 'Tick rates',
    path: 'tick-rates',
    idea: 'The same animation at fewer frames a second, with fixed_ticker.',
    page: TickRatesPage.new,
    group: .buildingBlocks,
    glyph: Glyph.blocks,
  ),
  Chapter(
    title: 'Implicit widgets',
    path: 'implicit-widgets',
    idea: 'Spring versions of AnimatedSize, AnimatedSwitcher and friends.',
    page: ImplicitWidgetsPage.new,
    group: .widgets,
    glyph: Glyph.squareStack,
  ),
  Chapter(
    title: 'Drag and drop',
    path: 'drag-and-drop',
    idea: 'Reorder a list. The dropped row lands on a spring.',
    page: DragAndDropPage.new,
    group: .widgets,
    glyph: Glyph.gripVertical,
  ),
  Chapter(
    title: 'DevTools',
    path: 'devtools',
    idea: 'Inspect, scrub, slow down and tune every animation while it runs.',
    page: DevToolsPage.new,
    group: .tools,
    glyph: Glyph.activity,
  ),
];

/// Finds the chapter titled [title].
Chapter chapterNamed(String title) =>
    chapters.firstWhere((chapter) => chapter.title == title);
