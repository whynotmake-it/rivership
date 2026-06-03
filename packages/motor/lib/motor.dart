/// A unified motion system for Flutter - physics-based springs and
/// duration-based curves under one API.
library motor;

export 'src/controllers/motion_controller.dart'
    show BoundedMotionController, MotionController, SequenceMotionController;
export 'src/controllers/phase_track_controller.dart';
export 'src/controllers/single_motion_controller.dart';
export 'src/controllers/track_controller.dart';
export 'src/motion.dart';
export 'src/motion_converter.dart';
export 'src/motion_curve.dart';
export 'src/motion_sequence.dart';
export 'src/motion_velocity_tracker.dart'
    show MotionVelocityEstimate, MotionVelocityTracker, VelocityTracking;
export 'src/phase_transition.dart';
export 'src/step.dart';
export 'src/track.dart';
export 'src/track_phase_timeline.dart';
export 'src/track_timeline.dart';
export 'src/widgets/motion/motion_padding.dart';
export 'src/widgets/motion_builder.dart';
export 'src/widgets/motion_draggable.dart';
export 'src/widgets/multi_track_motion_builder.dart';
export 'src/widgets/phase_track_builder.dart';
export 'src/widgets/sequence_motion_builder.dart';
export 'src/widgets/velocity_motion_builder.dart';
