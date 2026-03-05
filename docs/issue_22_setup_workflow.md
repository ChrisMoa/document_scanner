# Issue #22: Setup Workflow

## Tasks

- [x] Create branch `22-setup-workflow`
- [x] Replace `.github/workflows/flutter_build.yml` with Gitea-compatible CI/CD
  - [x] test job (analyze + test)
  - [x] version-bump job (auto-increment patch on push to main)
  - [x] build-android job (APK + AAB + Gitea Release upload)
  - [x] build-linux job (bundle + .deb + Gitea Release upload)
- [x] Restructure tests for CI (`test/core/`, `test/features/`)
- [x] Populate `CLAUDE.md` with project conventions
- [x] Populate `docs/TECH_STACK.md` with architecture reference
- [x] Populate `test/TEST_COVERAGE.md` with test inventory
- [x] Verify: `flutter analyze` (0 errors) — 126 info/warnings, 0 errors
- [x] Verify: `flutter test test/core/ test/features/` — 4 tests pass
- [x] Verify: Workflow YAML is valid
