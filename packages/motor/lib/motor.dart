/// A unified motion system for Flutter - physics-based springs and
/// duration-based curves under one API.
library motor;

export 'src/controllers/motion_controller.dart'
    show BoundedMotionController, MotionController, PhaseMotionController;
export 'src/controllers/single_motion_controller.dart';
export 'src/motion.dart';
export 'src/motion_converter.dart';
export 'src/motion_curve.dart';
export 'src/motion_sequence.dart';
export 'src/widgets/motion_builder.dart';
export 'src/widgets/motion_draggable.dart';
export 'src/widgets/sequence_motion_builder.dart';
export 'src/widgets/velocity_motion_builder.dart';
