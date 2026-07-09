# Changelog

All notable changes to BeeNut will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.0] - 2026-07-09

### Added
- Added custom target edit dialog for catalog configuration.
- Added virtual keyboard support for touch screen operators in settings dialogs.
- Added system resource usage charts for CPU, RAM, and thermals in Status settings.
- Added interactive file picker widget for model selection.
- Added product rules and guidelines file `PRODUCT.md`.

### Changed
- Replaced precompiled pill models with a modular configuration pattern, defaulting to `nuts_detection` model.
- Refined UI controls: control buttons, setting rows, panel decorations, and catalog/model tabs for a more robust user experience.
- Refined the ONNX YOLO engine to map dynamic output geometries more reliably.
- Updated automated unit and integration tests.

### Removed
- Removed large precompiled demo models (`yolo26n` and `pills_detection`) from repository history to keep bundle size lightweight.

## [v0] - 2026-07-08

### Added
- Launched BeeNut as the first product release.
- Added a clean Flutter kiosk UI for object-counting workflows.
- Added a native `beenutd` service for camera capture, preview transport, ONNX inference, GPIO, diagnostics, and shutdown.
- Added support for bundled and custom YOLO ONNX models with labels and manifests.
- Added a bundled pills detection demo model with `capsules` and `tablets` labels.
- Added preview inspection mode for bounding boxes, focused confidence labels, and dimmed background review.
- Added model, camera, GPIO, display, theme, target catalog, and hardware test settings.
- Added macOS, Linux desktop, and Raspberry Pi appliance packaging workflows.
- Added release validation, field diagnostics, checksums, and manifest tooling.

### Changed
- Branded the app with a clean white interface and `#F3C622` honey-yellow accents.
- Moved pause/resume to the main kiosk controls and shutdown to the Settings sidebar.
- Updated the splash screen to use the BeeNut logo.
- Refreshed the README with product positioning and app preview imagery.
