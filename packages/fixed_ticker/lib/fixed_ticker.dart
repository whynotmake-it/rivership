/// A drop-in Ticker replacement that optionally uses Timer.periodic at a fixed
/// interval with clock.now()-based elapsed tracking.
library fixed_ticker;

export 'src/fixed_ticker.dart';
export 'src/fixed_ticker_provider.dart';
export 'src/ticker_rate.dart';
export 'src/ticker_rate_scope.dart';
