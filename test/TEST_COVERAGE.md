# Test Coverage

**Total: 57 passing tests** across 7 test files

Run all tests with:
```bash
flutter test test/core/ test/features/
```

---

## Core

### Smoke Tests (`test/core/smoke_test.dart`)

| File | Tests | Covers |
|------|-------|--------|
| `smoke_test.dart` | 3 | App widget smoke test (MaterialApp renders), document naming convention (underscores instead of spaces), document scanner service exception message format |

### Model Tests (`test/core/models/`)

| File | Tests | Covers |
|------|-------|--------|
| `document_model_test.dart` | 9 | toJson/fromJson round-trip (all fields, nulls, empty lists, ISO 8601 dates), fromJson defaults, copyWith (update, preserve, imagePaths), constructor defaults |
| `scan_session_model_test.dart` | 9 | toJson/fromJson round-trip (all fields, empty imagePaths, ISO 8601), fromJson defaults, copyWith (update, preserve, imagePaths, id), constructor defaults |
| `settings_model_test.dart` | 11 | Default values, toJson/fromJson round-trip (custom + defaults), fromJson defaults (missing fields, int-to-double coercion), copyWith, equality/hashCode, toString |

### Service Tests (`test/core/services/`)

| File | Tests | Covers |
|------|-------|--------|
| `encryption_service_test.dart` | 19 | Key derivation (32-byte output, determinism, password/salt sensitivity), XOR encrypt/decrypt round-trip (various keys/IVs, empty data, single byte), constant-time comparison (equal, different, empty, length mismatch), full encrypt/decrypt flow with password-derived keys, wrong password detection |
| `pdf_service_test.dart` | 5 | generateFileName format (base name, timestamp regex, uniqueness, empty name, special characters) |

---

## Features

### Placeholder (`test/features/placeholder_test.dart`)

| File | Tests | Covers |
|------|-------|--------|
| `placeholder_test.dart` | 1 | Directory placeholder — replace with actual feature tests |

---

## Not Yet Covered

| Area | Reason |
|------|--------|
| StorageService CRUD | Requires Hive test setup with temp directories |
| PdfService image-to-PDF | Requires file system mocking |
| Nextcloud sync (NextcloudService) | Requires HTTP mocking (Dio) |
| EncryptionService integration | Public methods depend on StorageService (Hive boxes) |
| Camera/scanning services | Requires platform channel mocking |
| GoRouter navigation | No navigation tests |
| Theme provider | Requires SharedPreferences mocking |
| Document/Settings providers | Requires StorageService + SharedPreferences mocking |
| Widget/integration tests | No full widget tests for feature pages |

---

*Last updated: 2026-03-05*
