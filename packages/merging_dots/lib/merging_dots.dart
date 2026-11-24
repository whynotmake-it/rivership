/// Gooey, merging dots - on a grid or freeform, animated with motor and
/// rendered by fragment shaders.
library;

export 'package:motor/motor.dart'
    show
        CupertinoMotion,
        CurvedMotion,
        FixedTickerProviderStateMixin,
        LinearMotion,
        LoopMode,
        Motion,
        SingleFixedTickerProviderStateMixin,
        TickerRate,
        TickerRateScope;

export 'src/animation/dot_animator.dart';
export 'src/animation/dot_sequence.dart';
export 'src/animation/dot_stagger.dart';
export 'src/animation/motion_json.dart';
export 'src/character/dot_character.dart';
export 'src/character/dot_character_controller.dart';
export 'src/character/dot_character_view.dart';
export 'src/character/dot_idle.dart';
export 'src/model/dot_cloud.dart';
export 'src/model/dot_grid.dart';
export 'src/model/dot_scene.dart';
export 'src/model/dot_state.dart';
export 'src/presets/cloud_loaders.dart';
export 'src/presets/cloud_progress_loaders.dart';
export 'src/presets/dot_loader.dart';
export 'src/presets/dot_loaders.dart';
export 'src/presets/dot_presets.dart';
export 'src/presets/goo_loaders.dart';
export 'src/presets/grid_progress_loaders.dart';
export 'src/presets/tiles_loaders.dart';
export 'src/rendering/dot_shaders.dart';
export 'src/rendering/dot_styles.dart';
export 'src/rendering/render_dots.dart'
    show
        DotSceneModifier,
        RenderDotCloud,
        RenderDotGrid,
        RenderDotScene,
        kMaxGridValue;
export 'src/widgets/dot_views.dart';
