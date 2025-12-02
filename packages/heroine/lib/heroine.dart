/// An evolution on Heroes in Flutter, supporting Spring-based animations as
/// well as cleaner route transitions.
library heroine;

export 'package:motor/motor.dart'
    show
        CupertinoMotion,
        CurvedMotion,
        MaterialSpringMotion,
        Motion,
        SpringMotion;

export 'src/drag_dismissable.dart' show DragDismissable;
export 'src/heroine_route_mixin.dart'
    show HeroinePageRoute, HeroinePageRouteMixin, ReactToHeroineDismiss;
export 'src/heroine_velocity.dart' show HeroineVelocity;
export 'src/heroines.dart' show Heroine, HeroineController;
export 'src/scroll_drag_dismissable.dart' show ScrollDragDismissable;
export 'src/shuttle_builders.dart';
