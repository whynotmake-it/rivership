/// An evolution on Heroes in Flutter, supporting Spring-based animations as
/// well as cleaner route transitions.
library heroine;

export 'package:springster/springster.dart' show SimpleSpring;

export 'src/drag_dismissable.dart' show DragDismissable;
export 'src/heroine_route_mixin.dart'
    show HeroinePageRoute, HeroinePageRouteMixin, ReactToHeroineDismiss;
export 'src/heroines.dart' show Heroine, HeroineController;
export 'src/shuttle_builders.dart';
