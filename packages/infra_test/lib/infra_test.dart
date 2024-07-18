/// A package containing testing utilites to accompany the infra package.
library infra_test;

// Export common test utilities for convenience.
export 'package:clock/clock.dart';
export 'package:fake_async/fake_async.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:mocktail/mocktail.dart';

export 'src/matchers/is_shuffled.dart';
export 'src/riverpod/create_container.dart';
export 'src/riverpod/mock_provider_listener.dart';
