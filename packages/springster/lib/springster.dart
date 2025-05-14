/// Spring animations and simulations, simplified.
library springster;

export 'src/controllers/motion_controller.dart'
    show BoundedMotionController, MotionController;
export 'src/controllers/single_motion_controller.dart';
export 'src/legacy/spring_builder.dart';
export 'src/legacy/spring_draggable.dart';
export 'src/legacy/spring_simulation_controller.dart';
export 'src/legacy/spring_simulation_controller_2d.dart'
    hide Double2DMotionConverter;
export 'src/motion.dart';
export 'src/motion_converter.dart';
export 'src/spring_curve.dart';
export 'src/widgets/motion_builder.dart';
export 'src/widgets/motion_draggable.dart';
