import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves projects on the device, in the browser's local storage on web.
class ProjectStorage {
  static const _projectsKey = 'merging_dots.projects';
  static const _draftKey = 'merging_dots.draft';

  SharedPreferences? _preferences;

  Future<SharedPreferences?> get _prefs async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } on Object catch (error) {
      debugPrint('Saving is unavailable: $error');
      return null;
    }
  }

  /// All saved projects, newest first.
  Future<List<Project>> load() async {
    final prefs = await _prefs;
    final raw = prefs?.getString(_projectsKey);
    if (raw == null) return [];
    try {
      return [
        for (final json in jsonDecode(raw) as List)
          Project.fromJson(json as Map<String, Object?>),
      ];
    } on Object catch (error) {
      debugPrint('Could not read saved projects: $error');
      return [];
    }
  }

  /// Saves [projects], replacing what was saved.
  Future<void> save(List<Project> projects) async {
    final prefs = await _prefs;
    await prefs?.setString(
      _projectsKey,
      jsonEncode([for (final project in projects) project.toJson()]),
    );
  }

  /// The project that was open last, if any.
  Future<Project?> loadDraft() async {
    final prefs = await _prefs;
    final raw = prefs?.getString(_draftKey);
    if (raw == null) return null;
    try {
      return Project.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  /// Remembers [project] as the open one.
  Future<void> saveDraft(Project project) async {
    final prefs = await _prefs;
    await prefs?.setString(_draftKey, jsonEncode(project.toJson()));
  }
}
