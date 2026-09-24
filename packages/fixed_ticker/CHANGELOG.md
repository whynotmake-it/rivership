## 0.2.0

 - **FEAT**: synchronize equal and harmonic fixed ticker rates through a shared scheduler by default, with per-ticker and provider opt-out controls.

    Tickers with equal intervals request frames together, and intervals that are exact multiples (such as 30 fps and 15 fps) align on shared scheduler boundaries. Opt out per ticker or provider by overriding `shareTicks`.

## 0.1.0

 - **FEAT**: initial release of `FixedTicker`, fixed ticker provider mixins, `TickerRateScope`, and fixed ticker testing utilities.
