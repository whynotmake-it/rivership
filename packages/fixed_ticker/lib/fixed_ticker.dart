/// A drop-in Ticker replacement that uses Timer.periodic at a fixed interval
/// with clock.now()-based elapsed tracking.
library fixed_ticker;

export 'src/fixed_ticker.dart';
export 'src/fixed_ticker_provider.dart';
