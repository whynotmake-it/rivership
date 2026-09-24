import 'package:flutter/widgets.dart';
import 'package:motor_example/pages/fling.dart';
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
    idea: 'One controller animates every part of a control.',
    page: TogglePage.new,
  ),
  Chapter(
    title: 'Retarget',
    path: 'retarget',
    idea: 'Change your mind mid-flight.',
    page: RetargetPage.new,
  ),
  Chapter(
    title: 'Fling',
    path: 'fling',
    idea: 'Let go, and the gesture becomes a sequence.',
    page: FlingPage.new,
  ),
  Chapter(
    title: 'Steps',
    path: 'steps',
    idea: 'Choreograph a track as a list of steps.',
    page: StepsPage.new,
  ),
  Chapter(
    title: 'Sync',
    path: 'sync',
    idea: 'Tracks wait for each other at a barrier.',
    page: SyncPage.new,
  ),
  Chapter(
    title: 'Phases',
    path: 'phases',
    idea: 'Drag between named states, even mid-playback.',
    page: PhasesPage.new,
  ),
  Chapter(
    title: 'Scrub',
    path: 'scrub',
    idea: 'Pause, scrub and resume any choreography.',
    page: ScrubPage.new,
  ),
];

/// Finds the chapter titled [title].
Chapter chapterNamed(String title) =>
    chapters.firstWhere((chapter) => chapter.title == title);
