/// A unified motion system for Flutter - physics-based springs and duration-based curves under one API.
library motor;

export 'src/controllers/motion_controller.dart'
    show BoundedMotionController, MotionController;
export 'src/controllers/single_motion_controller.dart';
export 'src/motion.dart';
export 'src/motion_converter.dart';
export 'src/spring_curve.dart';
export 'src/widgets/motion_builder.dart';
export 'src/widgets/motion_draggable.dart';
