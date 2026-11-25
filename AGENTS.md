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

## Animation (Coil)
- Animate on Motor so a `TickerRateScope` can run every animation at a reduced frame rate. Use `TrackBuilder` or the motion builders; a looping effect such as a shimmer or a pulse is a `TrackBuilder` with a `TrackStep.loop`.
- When a controller is unavoidable, take its ticker from `SingleFixedTickerProviderStateMixin` / `FixedTickerProviderStateMixin`. Never use Flutter's `TickerProviderStateMixin`, `SingleTickerProviderStateMixin` or a bare `AnimationController`; `import_rules_test.dart` fails on them.
- Under reduced motion a looping effect rests, so the words must still say the status ("Searching…").

## Testing
- Don't add tests unless they cover real behavior, and each one covers a lot of it at once.
- Don't touch existing tests unless the instructions ask for a change in behavior that a test locks in. Then change only what that behavior change requires.
- No tests that pin values (durations, colors, alphas, sizes, counts, offsets).
- No tests that only check a widget or element is in the tree; they break whenever the UI changes.
- Test from the user's perspective, or the consumer's when testing an API. Use real cases, especially ones that could break.
- Test how it should work, not how it works today.
- Otherwise, don't add tests and don't touch tests.

## Changelogs
- Never edit a `CHANGELOG.md` by hand. Melos writes them from the conventional-commit messages at release, so put the user-facing summary in the commit message instead.

## Architecture
- Melos monorepo with packages in `packages/` directory
- Flutter/Dart project using hooks_riverpod for state management
- Each package has its own pubspec.yaml and follows standard Dart package structure
- Main library files export public API from `src/` directory

## Cursor Cloud specific instructions

Flutter `3.44.1` (pinned in `.fvmrc`, Dart `3.12.1`) is preinstalled at `/opt/flutter` with `flutter`, `dart`, and `melos` symlinked into `/usr/local/bin`, so they work in any shell. The startup update script runs `melos bootstrap`, which resolves the whole Dart pub workspace with a single root `flutter pub get` (this is a `resolution: workspace` monorepo — do not run per-package `pub get`).

Standard commands are in the `## Build/Test Commands` section above. Non-obvious caveats:

- `melos run generate` is a no-op: no package depends on `build_runner` and there are no generated files, so codegen is not part of the workflow (the aggregate example builds its `auto_route` config at runtime).
- `melos analyze` uses `dart analyze --fatal-infos`, so info-level lints fail the run. There is no committed lockfile, so upstream deprecations (e.g. `equatable`) can surface as new infos.
- The GitHub Pages deploy builds `apps/example` for web (`.github/workflows/deploy.yaml`: `cd apps/example && flutter build web --release --wasm`); run the same command to check the aggregate example.
- `apps/example` ships only `macos/` + `web/` platform folders and the per-package examples ship none. Run `apps/example` on web, or scaffold a platform temporarily (`flutter create --platforms web .`) for a per-package example and don't commit it.
- The Linux desktop target is not fully provisioned (missing `ninja-build`, `libgtk-3-dev`); install those before `flutter run -d linux`. Web (Chrome) works out of the box.