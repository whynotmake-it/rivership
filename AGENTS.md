# Agent Guidelines for Rivership

## Build/Test Commands
- `melos test` - Run all tests across packages
- `melos test:select` - Run tests for specific packages (interactive selection)
- `flutter test test/path/to/specific_test.dart` - Run single test file
- `melos analyze` - Run dart analyze with fatal-infos across all packages
- `melos coverage` - Generate test coverage for all packages
- `melos generate` - Run build_runner code generation

## Code Style
- Uses `lintervention` package for linting rules
- Library exports: Group by category (design, extensions, hooks, widgets)
- Extensions: Use descriptive names ending with "Tools" (e.g., `AsyncValueTools`)
- Documentation: Use triple-slash comments with detailed descriptions
- Immutable classes: Mark with `@immutable` annotation
- Constants: Use `const` constructors and static const fields
- Naming: Use descriptive names, avoid abbreviations
- Imports: Standard library first, then package imports, then relative imports
- Error handling: Use assert statements for parameter validation
- File structure: Organize by feature in `src/` subdirectories

## Architecture
- Melos monorepo with packages in `packages/` directory
- Flutter/Dart project using hooks_riverpod for state management
- Each package has its own pubspec.yaml and follows standard Dart package structure
- Main library files export public API from `src/` directory