/// Spring-driven versions of Flutter's implicit animation widgets, built on
/// Motor.
///
/// Every widget takes a `motion` instead of a duration and curve. Retargeting
/// one mid-flight keeps its velocity instead of restarting.
library motor_widgets;

export 'src/layout/padding_extended.dart' show PaddingExtended;
export 'src/motion_align.dart';
export 'src/motion_container.dart';
export 'src/motion_opacity.dart';
export 'src/motion_padding.dart';
export 'src/motion_positioned.dart';
export 'src/motion_rotation.dart';
export 'src/motion_scale.dart';
export 'src/motion_size.dart';
export 'src/motion_size_switcher.dart';
export 'src/motion_slide.dart';
export 'src/motion_switcher.dart';
export 'src/motion_transition.dart';
