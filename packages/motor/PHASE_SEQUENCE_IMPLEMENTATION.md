# Phase Sequence Implementation Guide

## Overview

This document outlines the implementation plan for creating a `PhaseSequenceController<P, T>` that extends `MotionController<T>`, replacing the unreliable standalone `PhaseController` with a more robust, type-safe approach.

## Problem Analysis

### Current Issues with PhaseController

1. **Complex State Management**: Multiple state variables (`_playing`, `_isForward`, `_currentPhaseIndex`) that can desynchronize
2. **Unreliable Scheduling**: Heavy reliance on `SchedulerBinding.instance.addPostFrameCallback` creates race conditions
3. **Redundant Wrapper**: Unnecessary abstraction layer over `MotionController`
4. **Timing Issues**: Phase transitions happen at unpredictable times
5. **Status Complexity**: Convoluted logic for determining animation status
6. **Loop Mode Fragmentation**: Loop handling scattered across multiple methods

### Root Cause

The fundamental issue is treating phase sequences as a separate animation system rather than as a series of coordinated `animateTo` operations within the existing ticker system. Additionally, the current approach suffers from type system limitations when trying to support different phase types on the same controller instance.

## Proposed Solution

### Design Principles

1. **Single Source of Truth**: Use the existing ticker system for all timing
2. **Natural Interruption**: Any `animateTo`/`stop` call automatically interrupts sequences  
3. **Velocity Preservation**: Each phase starts with current velocity for smooth transitions
4. **Type Safety**: Dedicated controller subclass for each phase type to avoid runtime casting
5. **Inheritance**: Leverage existing `MotionController` infrastructure rather than wrapping it
6. **Reliable Scheduling**: No callback-based scheduling, pure ticker-driven progression

### API Design

Create a new `PhaseSequenceController<P, T>` that extends `MotionController<T>`:

```dart
/// A MotionController specialized for playing phase sequences with type-safe phase access.
class PhaseSequenceController<P, T extends Object> extends MotionController<T> {
  /// Creates a PhaseSequenceController with the same parameters as MotionController
  PhaseSequenceController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  });

  PhaseSequenceController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  }) : super.motionPerDimension();
  
  /// Plays through a phase sequence starting from current value/velocity
  /// Returns a TickerFuture that completes when sequence finishes (non-looping)
  TickerFuture playSequence(
    PhaseSequence<P, T> sequence, {
    P? atPhase,
    void Function(P phase)? onPhaseChanged,
  });
  
  /// Current phase being animated to (null if not playing sequence)
  P? get currentSequencePhase;
  
  /// Whether a sequence is currently being played
  bool get isPlayingSequence;
  
  /// The active sequence (null if not playing)
  PhaseSequence<P, T>? get activeSequence;
  
  /// Progress through current sequence (0.0 to 1.0, accounting for loops)
  double get sequenceProgress;
}
```

### Type Safety Benefits

```dart
// Type-safe phase access - no casting required
PhaseSequenceController<Color, Offset> colorController = ...;
PhaseSequenceController<String, double> stringController = ...;

colorController.playSequence(colorPhaseSequence);
Color? currentColor = colorController.currentSequencePhase; // ✅ Type-safe

// Can't mix incompatible phase types at compile time
colorController.playSequence(stringPhaseSequence); // ❌ Compile error
```

## Implementation Plan

### Phase 1: Create PhaseSequenceController Subclass

#### 1.1 Define the subclass structure

```dart
/// A MotionController specialized for playing phase sequences with type-safe phase access.
class PhaseSequenceController<P, T extends Object> extends MotionController<T> {
  /// Creates a PhaseSequenceController with single motion for all dimensions
  PhaseSequenceController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  });

  /// Creates a PhaseSequenceController with motion per dimension
  PhaseSequenceController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    super.behavior,
  }) : super.motionPerDimension();

  // Phase sequence specific fields
  
  /// Active phase sequence being played
  PhaseSequence<P, T>? _activeSequence;

  /// Current phase index in the sequence
  int _currentSequencePhaseIndex = 0;

  /// Direction for ping-pong sequences (1 = forward, -1 = reverse)
  int _sequenceDirection = 1;

  /// Callback for phase changes
  void Function(P phase)? _onSequencePhaseChanged;

  /// Whether we're currently playing a sequence
  bool _isPlayingSequence = false;

  /// Target phase we're currently animating toward
  P? _currentSequencePhase;

  /// Ticker future for the sequence (completes when done)
  Completer<void>? _sequenceCompleter;
}
```

#### 1.2 Add getter implementations

```dart
/// Current phase being animated to (null if not playing sequence)
P? get currentSequencePhase => _currentSequencePhase;

/// Whether a sequence is currently being played
bool get isPlayingSequence => _isPlayingSequence;

/// The active sequence (null if not playing)
PhaseSequence<P, T>? get activeSequence => _activeSequence;

/// Progress through current sequence (0.0 to 1.0, accounting for loops)
double get sequenceProgress {
  if (_activeSequence == null || !_isPlayingSequence) return 0.0;
  
  final totalPhases = _activeSequence!.phases.length;
  if (totalPhases <= 1) return 1.0;
  
  return _currentSequencePhaseIndex / (totalPhases - 1);
}
```

### Phase 2: Implement Core Methods

#### 2.1 playSequence Implementation

```dart
/// Plays through a phase sequence starting from current value/velocity
/// Returns a TickerFuture that completes when sequence finishes (non-looping)
TickerFuture playSequence(
  PhaseSequence<P, T> sequence, {
  P? atPhase,
  void Function(P phase)? onPhaseChanged,
}) {
  // Stop any existing sequence by stopping underlying animation
  _stopSequence();
  
  if (sequence.phases.isEmpty) {
    return TickerFuture.complete();
  }
  
  // Initialize sequence state
  _activeSequence = sequence;
  _onSequencePhaseChanged = onPhaseChanged;
  _isPlayingSequence = true;
  _sequenceDirection = 1;
  _sequenceCompleter = Completer<void>();
  
  // Determine target phase
  final targetPhase = atPhase ?? sequence.phases.first;
  _currentSequencePhaseIndex = sequence.phases.indexOf(targetPhase);
  
  if (_currentSequencePhaseIndex == -1) {
    throw ArgumentError('Phase $targetPhase not found in sequence');
  }
  
  // Start the sequence by animating to the target phase
  _animateToPhaseInSequence(targetPhase);
  
  return TickerFuture(_sequenceCompleter!.future);
}
```

#### 2.2 Internal sequence stopping

```dart
/// Stops any active sequence (internal method)
void _stopSequence() {
  if (!_isPlayingSequence) return;
  
  _isPlayingSequence = false;
  _currentSequencePhase = null;
  _onSequencePhaseChanged = null;
  
  final completer = _sequenceCompleter;
  _sequenceCompleter = null;
  _activeSequence = null;
  
  // Complete the sequence future
  if (completer != null && !completer.isCompleted) {
    completer.complete();
  }
}
```

### Phase 3: Sequence Progression Logic

#### 3.1 Core phase animation method

```dart
void _animateToPhaseInSequence(P phase) {
  if (!_isPlayingSequence || _activeSequence == null) return;
  
  final sequence = _activeSequence!;
  _currentSequencePhase = phase;
  
  // Notify phase change
  _onSequencePhaseChanged?.call(phase);
  
  // Get motion and target for this phase
  final motion = sequence.motionForPhase(phase);
  final targetValue = sequence.valueForPhase(phase);
  
  // Update motion for this phase
  this.motion = motion;
  
  // Animate to the phase (preserves current velocity)
  super._animateToInternal(
    target: converter.normalize(targetValue),
    // Don't specify from/velocity - use current values for smooth transition
  );
}
```

#### 3.2 Override _tick to handle sequence progression

```dart
@override
void _tick(Duration elapsed) {
  // Call parent implementation for standard animation handling
  super._tick(elapsed);
  
  // Check if animation completed and we need to handle sequence progression
  if (!isAnimating && _isPlayingSequence) {
    _handleSequencePhaseCompletion();
  }
}
```

#### 3.3 Phase completion handler

```dart
void _handleSequencePhaseCompletion() {
  if (!_isPlayingSequence || _activeSequence == null) {
    _stopTicker();
    return;
  }
  
  final sequence = _activeSequence!;
  final totalPhases = sequence.phases.length;
  
  // Determine next phase index
  int nextIndex = _currentSequencePhaseIndex + _sequenceDirection;
  
  // Handle sequence boundaries
  if (nextIndex >= totalPhases) {
    // Reached end of sequence
    switch (sequence.loopMode) {
      case PhaseLoopMode.none:
        _completeSequence();
        return;
        
      case PhaseLoopMode.loop:
        nextIndex = 0;
        break;
        
      case PhaseLoopMode.seamless:
        // Jump to start without animation
        nextIndex = 0;
        _jumpToSequencePhase(nextIndex);
        return;
        
      case PhaseLoopMode.pingPong:
        _sequenceDirection = -1;
        nextIndex = totalPhases - 2;
        if (nextIndex < 0) nextIndex = 0;
        break;
    }
  } else if (nextIndex < 0) {
    // Reached start during ping-pong reverse
    _sequenceDirection = 1;
    nextIndex = 1;
    if (nextIndex >= totalPhases) nextIndex = totalPhases - 1;
  }
  
  _currentSequencePhaseIndex = nextIndex;
  
  // Continue to next phase
  final nextPhase = sequence.phases[nextIndex];
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (_isPlayingSequence) {
      _animateToPhaseInSequence(nextPhase);
    }
  });
}
```

### Phase 4: Override Methods to Handle Sequence Interruption

#### 4.1 Override animateTo to interrupt sequences

```dart
@override
TickerFuture animateTo(
  T target, {
  T? from,
  T? withVelocity,
}) {
  // Stop any active sequence when a manual animateTo is called
  _stopSequence();
  
  // Call parent implementation
  return super.animateTo(
    target,
    from: from,
    withVelocity: withVelocity,
  );
}
```

#### 4.2 Override stop to handle sequences

```dart
@override
TickerFuture stop({bool canceled = false}) {
  // Stop sequence when animation is stopped
  _stopSequence();
  
  // Call parent implementation
  return super.stop(canceled: canceled);
}
```

#### 4.3 Override dispose method

```dart
@override
void dispose() {
  _stopSequence();
  super.dispose();
}
```

### Phase 5: Helper Methods

#### 5.1 Sequence completion

```dart
void _completeSequence() {
  _isPlayingSequence = false;
  _currentSequencePhase = null;
  
  final completer = _sequenceCompleter;
  _sequenceCompleter = null;
  _activeSequence = null;
  _onSequencePhaseChanged = null;
  
  _stopTicker();
  
  if (completer != null && !completer.isCompleted) {
    completer.complete();
  }
}
```

#### 5.2 Seamless phase jumping

```dart
void _jumpToSequencePhase(int phaseIndex) {
  if (_activeSequence == null) return;
  
  final sequence = _activeSequence!;
  final phase = sequence.phases[phaseIndex];
  final targetValue = sequence.valueForPhase(phase);
  
  // Set value without animation
  value = targetValue;
  
  _currentSequencePhaseIndex = phaseIndex;
  _currentSequencePhase = phase;
  
  // Notify phase change
  _onSequencePhaseChanged?.call(phase);
  
  // Continue sequence after a frame
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (_isPlayingSequence) {
      _handleSequencePhaseCompletion();
    }
  });
}
```

## Testing Strategy

### Unit Tests Required

1. **Basic Sequence Playback**
   - Single phase sequence
   - Multi-phase sequence without looping
   - Sequence completion future resolves correctly

2. **Loop Modes**
   - `PhaseLoopMode.none` - stops at end
   - `PhaseLoopMode.loop` - restarts from beginning  
   - `PhaseLoopMode.seamless` - jumps to start without animation
   - `PhaseLoopMode.pingPong` - reverses direction at boundaries

3. **Interruption Behavior**
   - `animateTo` interrupts sequence
   - `stop` interrupts sequence
   - `stopSequence` stops cleanly
   - `dispose` cleans up properly

4. **Edge Cases**
   - Empty sequence
   - Single-phase sequence with different loop modes
   - Rapid start/stop calls
   - Invalid `startFromPhase`

5. **State Management**
   - `isPlayingSequence` accuracy
   - `currentSequencePhase` correctness
   - `sequenceProgress` calculation
   - Status reporting during sequences

### Integration Tests

1. **Widget Integration**
   - `MotionBuilder` with sequence playback
   - Phase change callbacks trigger rebuilds
   - Sequence interruption from user interaction

2. **Performance Tests**
   - Long sequences don't accumulate memory
   - Rapid sequence switching performs well
   - Loop modes don't cause frame drops

## Migration Path

### Phase 1: Implement New Controller
- Create `PhaseSequenceController<P, T>` as subclass of `MotionController<T>`
- Keep existing `PhaseController` for compatibility

### Phase 2: Update Examples
- Migrate example app to use `PhaseSequenceController.playSequence`
- Add new sequence examples showing type safety

### Phase 3: Deprecation
- Mark old `PhaseController` as deprecated
- Update documentation to recommend `PhaseSequenceController`

### Phase 4: Removal
- Remove old `PhaseController` in next major version
- Remove from exports

## Benefits Summary

✅ **Type Safety**: No runtime casting, compile-time phase type checking  
✅ **Reliability**: Ticker-driven instead of callback-scheduled
✅ **Performance**: Direct inheritance, no wrapper overhead  
✅ **Predictability**: Deterministic phase transition timing
✅ **Maintainability**: Clean inheritance hierarchy, reuses existing infrastructure
✅ **Flexibility**: Natural interruption and composition via method overrides
✅ **Consistency**: Same patterns as existing `MotionController` API

## Usage Examples

### Basic Usage
```dart
final controller = PhaseSequenceController<Color, Offset>(
  motion: Springs.smooth,
  vsync: this,
  converter: OffsetMotionConverter(),
  initialValue: Offset.zero,
);

final colorSequence = PhaseSequence.map({
  Colors.red: Offset(100, 100),
  Colors.green: Offset(200, 200), 
  Colors.blue: Offset(300, 300),
}, motion: (_) => Springs.bouncy);

await controller.playSequence(colorSequence);
```

### Advanced Usage with Phase Navigation
```dart
// Start sequence at specific phase
controller.playSequence(
  colorSequence, 
  atPhase: Colors.green,
  onPhaseChanged: (color) => print('Now at phase: $color'),
);

// Current phase is type-safe
Color? currentColor = controller.currentSequencePhase; // No casting needed!

// Smooth transition from normal animation to sequence
controller.animateTo(Offset(50, 50)); // Normal animation
// Later...
controller.playSequence(colorSequence); // Smoothly transitions to sequence
```

This implementation provides a robust, type-safe foundation for phase-based animations while maintaining the simplicity and reliability of the Motor animation system.