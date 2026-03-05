@docs/TECH_STACK.md
@test/TEST_COVERAGE.md

# Document Scanner — Claude Rules

## Code Conventions

- Use `Theme.of(context)` / `ref.watch(themeProvider)` for **all** colors — never hardcode `Colors.xxx` (exception: semantic like `Colors.amber` for stars)
- Use `.withValues(alpha: 0.x)` — **not** `.withOpacity()`
- Wrap text in `Flexible` or `Expanded` inside `Row` to prevent overflow
- Use Riverpod providers (not raw `setState`)

### UI Kit (convention — to be created)

Use shared widgets from `core/widgets/app_ui_kit.dart`:
- `AppCard`, `AppDialog`, `AppSnackBar`, `AppTextField`
- `AppSpacing` (e.g., `AppSpacing.paddingAllMd`, `AppSpacing.verticalXs`)
- `AppRadius` for border radii

Use `AppSpacing` constants instead of raw `EdgeInsets.all(16)` or `SizedBox(height: 8)`.

## Commands

```bash
flutter test test/core/ test/features/
flutter analyze
dart run build_runner build --delete-conflicting-outputs
```

## Workflow

- Run `flutter analyze` (0 errors) + `flutter test test/core/ test/features/` after implementation
- Update `test/TEST_COVERAGE.md` if new tests are added
- Create issue todo list at `docs/issue_#<issue_name>.md`
