import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/storage.dart';

/// What a drag on the freeform canvas does.
enum CloudTool { move, add }

/// What a stroke on the grid does.
enum GridTool {
  /// Switches cells: the first cell of a stroke decides on or off.
  flip,

  /// Only adds ink.
  draw,

  /// Only removes ink.
  erase,
}

/// Which mirror copies a grid stroke paints too.
enum Symmetry {
  off,
  vertical,
  horizontal,
  both;

  bool get mirrorsColumns => this == vertical || this == both;
  bool get mirrorsRows => this == horizontal || this == both;
}

/// The editor's state: the open project, the selection and the library of
/// saved projects.
class EditorController extends ChangeNotifier {
  EditorController({ProjectStorage? storage, Project? project})
    : _storage = storage ?? ProjectStorage(),
      _project = project ?? Project.blank();

  final ProjectStorage _storage;

  Project _project;
  Project get project => _project;

  int _frame = 0;

  /// The frame being edited.
  int get frame => _frame.clamp(0, _project.frameCount - 1);

  bool _playing = false;

  /// Whether the animation plays instead of the edited frame showing.
  bool get playing => _playing;

  /// The frame the playing animation is on.
  final ValueNotifier<int> playingFrame = ValueNotifier(0);

  double _brush = 1;

  GridTool _gridTool = GridTool.flip;
  GridTool get gridTool => _gridTool;

  Symmetry _symmetry = Symmetry.off;
  Symmetry get symmetry => _symmetry;

  /// The value painting a grid cell sets. 0 erases.
  double get brush => _brush;

  CloudTool _cloudTool = CloudTool.add;
  CloudTool get cloudTool => _cloudTool;

  int? _selectedDot;

  /// The selected dot of the freeform canvas.
  int? get selectedDot {
    final selected = _selectedDot;
    if (selected == null) return null;
    return selected < currentCloud.dots.length ? selected : null;
  }

  bool _onionSkin = true;

  /// Whether the previous frame shows faintly behind the edited one.
  bool get onionSkin => _onionSkin;

  final List<Project> _undo = [];
  final List<Project> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  List<Project> _library = [];

  /// The saved projects.
  List<Project> get library => _library;

  Timer? _draftTimer;

  /// Loads the library and the project that was open last.
  Future<void> restore() async {
    _library = await _storage.load();
    final draft = await _storage.loadDraft();
    if (draft != null) {
      _project = draft;
      _frame = 0;
    }
    notifyListeners();
  }

  DotGrid get currentGrid => _project.grid.frames[frame].state;
  DotCloud get currentCloud => _project.cloud.frames[frame].state;

  /// The frame before the edited one, for the onion skin.
  int? get previousFrame {
    if (_project.frameCount < 2) return null;
    return frame == 0 ? _project.frameCount - 1 : frame - 1;
  }

  // Editing

  /// Remembers the project for undo. Call it once before a group of edits,
  /// like at the start of a stroke.
  void checkpoint() {
    _undo.add(_project);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
  }

  void _set(Project project, {bool checkpoint = true}) {
    if (checkpoint) this.checkpoint();
    _project = project;
    _changed();
  }

  void _changed() {
    notifyListeners();
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_storage.saveDraft(_project));
    });
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_project);
    _project = _undo.removeLast();
    _changed();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_project);
    _project = _redo.removeLast();
    _changed();
  }

  void setMode(DotMode mode) {
    if (mode == _project.mode) return;
    _frame = 0;
    _selectedDot = null;
    _set(_project.copyWith(mode: mode), checkpoint: false);
  }

  void rename(String name) => _set(_project.copyWith(name: name));

  void setBrush(double value) {
    _brush = value;
    notifyListeners();
  }

  void setGridTool(GridTool tool) {
    _gridTool = tool;
    notifyListeners();
  }

  void setSymmetry(Symmetry symmetry) {
    _symmetry = symmetry;
    notifyListeners();
  }

  void setCloudTool(CloudTool tool) {
    _cloudTool = tool;
    notifyListeners();
  }

  void setOnionSkin({required bool enabled}) {
    _onionSkin = enabled;
    notifyListeners();
  }

  void setPlaying({required bool playing}) {
    _playing = playing;
    notifyListeners();
  }

  void selectFrame(int index) {
    _frame = index.clamp(0, _project.frameCount - 1);
    _playing = false;
    notifyListeners();
  }

  // Grid

  void _setGridFrame(DotGrid grid, {bool checkpoint = false}) {
    final frames = [..._project.grid.frames];
    frames[frame] = frames[frame].copyWith(state: grid);
    _set(
      _project.copyWith(grid: withFrames(_project.grid, frames)),
      checkpoint: checkpoint,
    );
  }

  /// Sets the cell at [column] and [row] of the edited frame. Call
  /// [checkpoint] before a stroke.
  void paintCell(int column, int row, double value) {
    var grid = currentGrid;
    final columns = {
      column,
      if (_symmetry.mirrorsColumns) grid.columns - 1 - column,
    };
    final rows = {row, if (_symmetry.mirrorsRows) grid.rows - 1 - row};
    for (final c in columns) {
      for (final r in rows) {
        if (grid.valueAt(c, r) != value) grid = grid.withValue(c, r, value);
      }
    }
    if (identical(grid, currentGrid)) return;
    _setGridFrame(grid);
  }

  /// The value a stroke starting on [column] and [row] paints, from the
  /// tool and the brush.
  double strokeValue(int column, int row) {
    final ink = _brush == 0 ? 1.0 : _brush;
    return switch (_gridTool) {
      GridTool.draw => ink,
      GridTool.erase => 0,
      GridTool.flip => currentGrid.valueAt(column, row) > 0 ? 0 : ink,
    };
  }

  /// Grows or shrinks every frame of the grid by [delta] cells per side,
  /// keeping the content centered.
  void stepGridSize(int delta) {
    final grid = currentGrid;
    final columns = (grid.columns + delta).clamp(2, 32);
    final rows = (grid.rows + delta).clamp(2, 32);
    if (columns == grid.columns && rows == grid.rows) return;
    resizeGrid(columns, rows);
  }

  void clearFrame() {
    switch (_project.mode) {
      case DotMode.grid:
        final grid = currentGrid;
        _setGridFrame(DotGrid(grid.columns, grid.rows), checkpoint: true);
      case DotMode.cloud:
        _setCloudFrame(
          DotCloud([
            for (final dot in currentCloud.dots) dot.copyWith(radius: 0),
          ], size: currentCloud.size),
          checkpoint: true,
        );
    }
  }

  void fillFrame() => _setGridFrame(
    currentGrid.map((_, _, _) => _brush == 0 ? 1 : _brush),
    checkpoint: true,
  );

  void invertFrame() => _setGridFrame(
    currentGrid.map((_, _, v) => v > 0 ? 0 : 1),
    checkpoint: true,
  );

  /// Moves the content of the edited frame by whole cells.
  void shiftFrame(int dx, int dy) {
    final grid = currentGrid;
    _setGridFrame(
      DotGrid.generate(grid.columns, grid.rows, (column, row) {
        final c = column - dx;
        final r = row - dy;
        if (c < 0 || r < 0 || c >= grid.columns || r >= grid.rows) return 0;
        return grid.valueAt(c, r);
      }),
      checkpoint: true,
    );
  }

  /// Resizes every frame of the grid.
  void resizeGrid(int columns, int rows) {
    final frames = [
      for (final frame in _project.grid.frames)
        frame.copyWith(state: frame.state.resized(columns, rows)),
    ];
    _set(_project.copyWith(grid: withFrames(_project.grid, frames)));
  }

  void setGridStyle(DotGridStyle style) =>
      _set(_project.copyWith(gridStyle: style), checkpoint: false);

  // Cloud

  void _setCloudFrames(
    List<DotKeyframe<DotCloud>> frames, {
    bool checkpoint = false,
  }) {
    _set(
      _project.copyWith(cloud: withFrames(_project.cloud, frames)),
      checkpoint: checkpoint,
    );
  }

  void _setCloudFrame(DotCloud cloud, {bool checkpoint = false}) {
    final frames = [..._project.cloud.frames];
    frames[frame] = frames[frame].copyWith(state: cloud);
    _setCloudFrames(frames, checkpoint: checkpoint);
  }

  /// Adds a dot at [position] to every frame, so frames stay matched.
  void addDot(Offset position, {double radius = 10}) {
    if (currentCloud.dots.length >= DotCloud.maxDots) return;
    final dot = Dot(position.dx, position.dy, radius);
    _setCloudFrames([
      for (final frame in _project.cloud.frames)
        frame.copyWith(state: frame.state.withAdded(dot)),
    ], checkpoint: true);
    _selectedDot = currentCloud.dots.length - 1;
    notifyListeners();
  }

  /// Moves dot [index] of the edited frame. Call [checkpoint] before a drag.
  void moveDot(int index, Offset position) {
    final cloud = currentCloud;
    final size = cloud.size;
    _setCloudFrame(
      cloud.withDot(
        index,
        cloud.dots[index].copyWith(
          x: position.dx.clamp(0, size.width),
          y: position.dy.clamp(0, size.height),
        ),
      ),
    );
  }

  void setDotRadius(int index, double radius) {
    final cloud = currentCloud;
    _setCloudFrame(
      cloud.withDot(index, cloud.dots[index].copyWith(radius: radius)),
    );
  }

  /// Removes dot [index] from every frame.
  void removeDot(int index) {
    _setCloudFrames([
      for (final frame in _project.cloud.frames)
        frame.copyWith(state: frame.state.withRemoved(index)),
    ], checkpoint: true);
    _selectedDot = null;
    notifyListeners();
  }

  void selectDot(int? index) {
    _selectedDot = index;
    notifyListeners();
  }

  void setCloudStyle(DotCloudStyle style) =>
      _set(_project.copyWith(cloudStyle: style), checkpoint: false);

  // Frames

  /// Inserts a copy of the edited frame after it and selects it.
  void duplicateFrame() {
    switch (_project.mode) {
      case DotMode.grid:
        final frames = [..._project.grid.frames]
          ..insert(frame + 1, _project.grid.frames[frame]);
        _set(_project.copyWith(grid: withFrames(_project.grid, frames)));
      case DotMode.cloud:
        final frames = [..._project.cloud.frames]
          ..insert(frame + 1, _project.cloud.frames[frame]);
        _set(_project.copyWith(cloud: withFrames(_project.cloud, frames)));
    }
    selectFrame(frame + 1);
  }

  void removeFrame() {
    if (_project.frameCount < 2) return;
    switch (_project.mode) {
      case DotMode.grid:
        final frames = [..._project.grid.frames]..removeAt(frame);
        _set(_project.copyWith(grid: withFrames(_project.grid, frames)));
      case DotMode.cloud:
        final frames = [..._project.cloud.frames]..removeAt(frame);
        _set(_project.copyWith(cloud: withFrames(_project.cloud, frames)));
    }
    selectFrame(frame);
  }

  /// Moves the edited frame by [delta] places.
  void moveFrame(int delta) {
    final to = frame + delta;
    if (to < 0 || to >= _project.frameCount) return;
    List<T> moved<T>(List<T> list) {
      final copy = [...list];
      final item = copy.removeAt(frame);
      return copy..insert(to, item);
    }

    switch (_project.mode) {
      case DotMode.grid:
        _set(
          _project.copyWith(
            grid: withFrames(_project.grid, moved(_project.grid.frames)),
          ),
        );
      case DotMode.cloud:
        _set(
          _project.copyWith(
            cloud: withFrames(_project.cloud, moved(_project.cloud.frames)),
          ),
        );
    }
    selectFrame(to);
  }

  void setHold(Duration hold) {
    switch (_project.mode) {
      case DotMode.grid:
        final frames = [..._project.grid.frames];
        frames[frame] = frames[frame].copyWith(hold: hold);
        _set(
          _project.copyWith(grid: withFrames(_project.grid, frames)),
          checkpoint: false,
        );
      case DotMode.cloud:
        final frames = [..._project.cloud.frames];
        frames[frame] = frames[frame].copyWith(hold: hold);
        _set(
          _project.copyWith(cloud: withFrames(_project.cloud, frames)),
          checkpoint: false,
        );
    }
  }

  // Sequence settings

  void setMotion(Motion motion) => _setSettings(motion: motion);
  void setStagger(DotStagger stagger) => _setSettings(stagger: stagger);
  void setLoop(LoopMode loop) => _setSettings(loop: loop);

  void _setSettings({Motion? motion, DotStagger? stagger, LoopMode? loop}) {
    _set(switch (_project.mode) {
      DotMode.grid => _project.copyWith(
        grid: withSettings(
          _project.grid,
          motion: motion,
          stagger: stagger,
          loop: loop,
        ),
      ),
      DotMode.cloud => _project.copyWith(
        cloud: withSettings(
          _project.cloud,
          motion: motion,
          stagger: stagger,
          loop: loop,
        ),
      ),
    }, checkpoint: false);
  }

  // Projects

  /// Opens [project], keeping the current one undoable.
  void open(Project project) {
    _frame = 0;
    _selectedDot = null;
    _playing = project.frameCount > 1;
    _set(project);
  }

  void newProject() => open(Project.blank());

  /// Saves the open project to the library, replacing one with its name.
  Future<void> saveToLibrary() async {
    _library = [
      _project,
      for (final saved in _library)
        if (saved.name != _project.name) saved,
    ];
    notifyListeners();
    await _storage.save(_library);
  }

  Future<void> deleteFromLibrary(Project project) async {
    _library = [
      for (final saved in _library)
        if (saved.name != project.name) saved,
    ];
    notifyListeners();
    await _storage.save(_library);
  }

  /// Opens JSON exported by the editor: a whole project, or an animation
  /// from the export sheet. Returns an error message if it can't be read.
  String? importJson(String source) {
    try {
      final json = jsonDecode(source) as Map<String, Object?>;
      if (json.containsKey('grid') && json.containsKey('cloud')) {
        open(Project.fromJson(json));
        return null;
      }
      final style = json['style'] as Map<String, Object?>? ?? const {};
      final blank = Project.blank(name: _project.name);
      open(
        json['kind'] == 'cloud'
            ? blank.copyWith(
                mode: DotMode.cloud,
                cloud: DotSequence.cloudFromJson(json),
                cloudStyle: DotCloudStyle.fromJson(style),
              )
            : blank.copyWith(
                grid: DotSequence.gridFromJson(json),
                gridStyle: DotGridStyle.fromJson(style),
              ),
      );
      return null;
    } on Object catch (error) {
      return 'That doesn\'t look like merging dots JSON ($error).';
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    playingFrame.dispose();
    super.dispose();
  }
}
