import 'package:flutter/widgets.dart';
import 'package:motor_example/pages/card_stack.dart';
import 'package:motor_example/pages/phases.dart';
import 'package:motor_example/pages/retarget.dart';
import 'package:motor_example/pages/scrub.dart';
import 'package:motor_example/pages/steps.dart';
import 'package:motor_example/pages/sync.dart';
import 'package:motor_example/pages/toggle.dart';

/// The small drawing on a chapter's card on the home page.
enum ChapterGlyph { toggle, retarget, cardStack, steps, sync, phases, scrub }

/// One lesson in the gallery.
@immutable
class Chapter {
  const Chapter({
    required this.title,
    required this.path,
    required this.idea,
    required this.page,
    required this.glyph,
  });

  /// Also the route name.
  final String title;

  final String path;

  /// What the chapter teaches, in a few words.
  final String idea;

  final Widget Function() page;

  /// The drawing on the chapter's card.
  final ChapterGlyph glyph;

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
    idea:
        'One controller animates every part, and a drag hands over its speed.',
    page: TogglePage.new,
    glyph: .toggle,
  ),
  Chapter(
    title: 'Retarget',
    path: 'retarget',
    idea: 'Retarget mid-flight without a jump. Springs keep their speed.',
    page: RetargetPage.new,
    glyph: .retarget,
  ),
  Chapter(
    title: 'Card stack',
    path: 'card-stack',
    idea: 'Throw a card. It keeps your speed and returns under the stack.',
    page: CardStackPage.new,
    glyph: .cardStack,
  ),
  Chapter(
    title: 'Steps',
    path: 'steps',
    idea: 'Each track runs its own steps, with a different motion per step.',
    page: StepsPage.new,
    glyph: .steps,
  ),
  Chapter(
    title: 'Sync',
    path: 'sync',
    idea: 'Tracks wait for each other at a sync barrier.',
    page: SyncPage.new,
    glyph: .sync,
  ),
  Chapter(
    title: 'Phases',
    path: 'phases',
    idea: 'Named layouts you can drag between, even while they autoplay.',
    page: PhasesPage.new,
    glyph: .phases,
  ),
  Chapter(
    title: 'Scrub',
    path: 'scrub',
    idea: 'Scrub to any moment, then play on from there.',
    page: ScrubPage.new,
    glyph: .scrub,
  ),
];

/// Finds the chapter titled [title].
Chapter chapterNamed(String title) =>
    chapters.firstWhere((chapter) => chapter.title == title);
