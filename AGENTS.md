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

## Cursor Cloud specific instructions

Flutter `3.44.1` (pinned in `.fvmrc`, Dart `3.12.1`) is preinstalled at `/opt/flutter` with `flutter`, `dart`, and `melos` symlinked into `/usr/local/bin`, so they work in any shell. The startup update script runs `melos bootstrap`, which resolves the whole Dart pub workspace with a single root `flutter pub get` (this is a `resolution: workspace` monorepo — do not run per-package `pub get`).

Standard commands are in the `## Build/Test Commands` section above. Non-obvious caveats:

- `melos run generate` is a no-op: no package depends on `build_runner` and there are no generated files, so codegen is not part of the workflow (the aggregate example builds its `auto_route` config at runtime).
- `melos analyze` uses `dart analyze --fatal-infos`, so info-level lints fail the run. `heroine`, `motor`, and `snaptest` currently report a pre-existing `EquatableMixin` deprecation info (upstream `equatable` drift, since there is no committed lockfile). This is not an environment problem.
- Web target and the glass examples: `motor/example` and `springster/example` run on web (`flutter run -d web-server --web-port 8080`). The aggregate `apps/example`, `heroine/example`, and `stupid_simple_sheet/example` pull in the `liquid_glass_renderer` git package, whose shaders cannot be translated to SkSL. Their Dart code compiles and the shaders compile fine for Impeller (verified with `impellerc --runtime-stage-vulkan`), but the **web** build hard-fails with `ShaderCompilerException` (exit 1) during asset bundling, so the dev server never starts — this is a web/CanvasKit-only limitation, not a warning. `apps/example` ships only `macos/` + `web/` platform folders and the per-package examples ship none, so running the glass examples on this Linux VM first requires scaffolding desktop support (`flutter create .`); use `springster`/`motor` on web for a quick smoke test instead.
- The Linux desktop target is not fully provisioned (missing `ninja-build`, `libgtk-3-dev`); install those before `flutter run -d linux`. Web (Chrome) works out of the box.