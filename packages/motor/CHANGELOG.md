## 1.0.0-dev.1

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: remove experimental changes from `springster` and add to new `motor` package instead (#117).

    * refactor!: remove legacy `Spring` widgets. Use `Motion` widgets instead
    
    * refactor!: renamed package to `motor`
    
    * chore: version
    
    * chore: add back springster at last released version
    
    * chore: add back legacy springster
    
    * rename `Spring` to `SpringMotion`
    
    * refactor!: renamed `Spring` to `SpringMotion`
    
    * more stuff
    
    * feat!: add `VelocityMotionBuilder`
    
    * feat: add `VelocityMotionBuilder`, which also passes the current velocity to the builder
    
    * add velocity stuff to example
    
    * linter love
    
    * docs: mention motor upgrade in springster readme
    
    * return springster version


## 1.0.0-dev.0

Initial release of Motor - a unified motion system for Flutter.

### Features 🎯

- **Unified Motion API** - One consistent interface for springs, curves, and custom motions
- **Physics & Duration Based** - Choose between spring physics or traditional duration/curve animations  
- **Apple Design System** - Built-in CupertinoMotion presets matching iOS animations
- **Multi-dimensional** - Animate complex types like Offset, Size, and Rect with independent physics per dimension
- **Interactive Widgets** - Motion-driven draggable widgets with natural return animations
- **Flutter Integration** - Works seamlessly with existing Flutter animation patterns

### Core Components

- **Motion System**: `Motion`, `SpringMotion`, `CurvedMotion`, `CupertinoMotion`
- **Widgets**: `SingleMotionBuilder`, `MotionBuilder`, `MotionDraggable`
- **Controllers**: `MotionController`, `SingleMotionController`, `BoundedMotionController`
- **Converters**: `MotionConverter`, `OffsetMotionConverter`, `SizeMotionConverter`, `RectMotionConverter`, `AlignmentMotionConverter`
- **Utilities**: `SpringCurve`, `SpringDescriptionExtension`

### CupertinoMotion Presets

- `CupertinoMotion.standard` - Default iOS spring with smooth motion
- `CupertinoMotion.smooth` - Smooth spring animation with no bounce
- `CupertinoMotion.bouncy` - Spring with higher bounce for playful interactions
- `CupertinoMotion.snappy` - Snappy spring with small bounce that feels responsive
- `CupertinoMotion.interactive` - Interactive spring with lower response for user-driven animations