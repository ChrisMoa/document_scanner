# Test Coverage

**Total: 4 passing tests** across 2 test files

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
| DocumentModel serialization | No unit tests for Hive model round-trips |
| ScanSessionModel serialization | No unit tests for Hive model round-trips |
| StorageService CRUD | Requires Hive test setup |
| PDF generation (PdfService) | Requires file system mocking |
| Nextcloud sync (NextcloudService) | Requires HTTP mocking (Dio) |
| Encryption (EncryptionService) | No unit tests yet |
| Camera/scanning services | Requires platform channel mocking |
| GoRouter navigation | No navigation tests |
| Theme provider | No state management tests |
| Widget/integration tests | No full widget tests for feature pages |

---

*Last updated: 2026-03-04*
