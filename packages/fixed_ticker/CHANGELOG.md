## 0.1.1

 - **FEAT**(fixed_ticker): synchronize shared tick rates (#300).

    * feat(fixed_ticker): synchronize shared tick rates
    
    
    
    * style(fixed_ticker): satisfy scheduler lint
    
    
    
    * test(fixed_ticker): cover rounded fps harmonics
    
    
    
    * test(fixed_ticker): add shared scheduler adversarial coverage
    
    
    
    * fix(fixed_ticker): preserve cadence when merging rates
    
    
    
    * docs(fixed_ticker): demonstrate shared tick alignment
    
    
    
    * docs(fixed_ticker): make shared phase transition visible
    
    
    
    * docs(fixed_ticker): clarify shared phase transition
    
    
    
    ---------

 - **FEAT**: fixed_ticker package (#276).

    * good start
    
    * kinda but drifting
    
    * no drift


## Unreleased

- **FEAT**: synchronize equal and harmonic fixed ticker rates through a shared scheduler by default, with per-ticker and provider opt-out controls.

## 0.1.0

 - **FEAT**: initial release of `FixedTicker`, fixed ticker provider mixins, `TickerRateScope`, and fixed ticker testing utilities.
