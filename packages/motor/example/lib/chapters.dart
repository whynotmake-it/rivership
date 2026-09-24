import 'package:flutter/widgets.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/phases.dart';
import 'package:motor_example/pages/retarget.dart';
import 'package:motor_example/pages/scrub.dart';
import 'package:motor_example/pages/steps.dart';
import 'package:motor_example/pages/sync.dart';
import 'package:motor_example/pages/toggle.dart';

/// One lesson in the gallery.
@immutable
class Chapter {
  const Chapter({
    required this.title,
    required this.path,
    required this.idea,
    required this.page,
  });

  /// Also the route name.
  final String title;

  final String path;

  /// What the chapter teaches, in a few words.
  final String idea;

  final Widget Function() page;

  /// The chapter's position, starting at "01".
  String get number => (chapters.indexOf(this) + 1).toString().padLeft(2, '0');

  /// The following chapter, if any.
  Chapter? get next {
    final index = chapters.indexOf(this);
    return index + 1 < chapters.length ? chapters[index + 1] : null;
  }
}

/// The gallery, in reading order.
final chapters = [
  Chapter(
    title: 'Toggle',
    path: 'toggle',
    idea: 'Drive a switch and a like button, each with one controller.',
    page: TogglePage.new,
  ),
  Chapter(
    title: 'Retarget',
    path: 'retarget',
    idea: 'Give an animation a new target halfway without losing speed.',
    page: RetargetPage.new,
  ),
  Chapter(
    title: 'Card stack',
    path: 'card-stack',
    idea: 'Throw a card off the stack and watch it curve back underneath.',
    page: CardStackPage.new,
  ),
  Chapter(
    title: 'Steps',
    path: 'steps',
    idea: 'Run each track through its own list of steps.',
    page: StepsPage.new,
  ),
  Chapter(
    title: 'Sync',
    path: 'sync',
    idea: 'Make tracks wait for each other before they move on.',
    page: SyncPage.new,
  ),
  Chapter(
    title: 'Phases',
    path: 'phases',
    idea: 'Move between named layouts by tapping or dragging.',
    page: PhasesPage.new,
  ),
  Chapter(
    title: 'Scrub',
    path: 'scrub',
    idea: 'Pause an animation, drag to any moment, and resume.',
    page: ScrubPage.new,
  ),
];

/// Finds the chapter titled [title].
Chapter chapterNamed(String title) =>
    chapters.firstWhere((chapter) => chapter.title == title);
