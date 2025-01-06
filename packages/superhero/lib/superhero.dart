/// An evolution on Heroes in Flutter, supporting Spring-based animations as well as cleaner route transitions.
library superhero;

export 'package:springster/springster.dart' show SimpleSpring;

export 'src/drag_dismissable.dart' show DragDismissable;
export 'src/superhero_route_mixin.dart'
    show SuperheroPageRoute, SuperheroPageRouteMixin;
export 'src/superheroes.dart' show Superhero, SuperheroController;
