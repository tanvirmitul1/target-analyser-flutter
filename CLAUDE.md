# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dependencies
flutter pub get

# Run (debug / release)
flutter run
flutter run --release

# Code generation (Riverpod providers, Freezed models, JSON serialization)
flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run build_runner watch --delete-conflicting-outputs

# Lint & analyze
flutter analyze

# Tests
flutter test
```

> Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from lint. Always run `build_runner` after modifying annotated models or providers.

## Architecture

**Pattern:** Clean Architecture (domain-driven) + Riverpod state management. Each feature under `lib/features/` follows the same three-layer layout: `data/`, `domain/`, `presentation/`.

### Feature Modules

| Feature | Purpose |
|---|---|
| `home` | Soldier ID input, form validation, entry point |
| `camera` | Live camera preview, capture, zoom/flash/focus |
| `processing` | Image processing via native OpenCV; pure-Dart fallback |
| `analysis` | Geometric shot-pattern analysis and shooter-error detection |
| `result` | Results display; `ScanFlowProvider` orchestrates the full pipeline |
| `storage` | SQLite persistence for soldiers and shot records |
| `audio` | Coaching audio playback keyed to shooter error type |

### Core (`lib/core/`)

- `services/DatabaseService` – singleton SQLite init, migrations (v1→v2), access
- `services/OpenCvBridge` – `MethodChannel('image_processor')` → Kotlin/OpenCV; returns JSON with shot coordinates and processed image path
- `config/DebugConfig` – feature flags (debug mode toggles native debug annotations)
- `utils/` – `AppLogger`, `Result<T>` type, `ImageCompressor`

### State Management

All providers use Riverpod (`flutter_riverpod ^2.5.1`) with code generation (`riverpod_annotation`). The central orchestrator is **`ScanFlowProvider`** (family notifier in `result/`), which drives the full pipeline sequentially:

1. `ProcessImageUseCase` → `OpenCvBridge` → native processing
2. `ShotAnalysisService` → pattern detection + error classification
3. Soldier upsert + `ShotRecord` insert via `DatabaseService`
4. Image size decode for crosshair overlay
5. `AudioProvider` → play coaching sound

### Native Bridge

- **Channel:** `image_processor`
- **Method:** `processImage({path: String, debugMode: bool})` → JSON string
- **Fallback:** `PureDartProcessingDatasource` used when native call fails
- Implemented in `android/app/` (Kotlin + OpenCV)

### Database Schema (v2)

- `soldiers` — `id TEXT PRIMARY KEY`
- `soldier_shots` — per-shot analytics linked to soldier (x, y, distance, angle, pattern, error_type, created_at)
- Migrations are additive only; foreign keys enabled; transactions are batched atomic

### Key Domain Types

- `ShotPattern` – pattern type (horizontal/vertical/bifocal/scattered), shots list, error type
- `ShooterError` – enum (jerk/buck/flinch) inferred from clock-hour clustering
- `ProcessedImage` – native output with normalized coordinates + processed image path
- `ShotRecord` – full analytics row stored in SQLite

## Linting

`analysis_options.yaml` enforces 40+ rules including single quotes, relative imports, final fields/locals, explicit return types, and no dynamic calls. `riverpod_lint` is active. Obey existing style when modifying files.
