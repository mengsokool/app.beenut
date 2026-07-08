# Contributing to BeeNut

BeeNut is a Flutter kiosk UI plus the `beenutd` native service. Changes should
keep the product usable in three environments:

- Desktop development on macOS or Linux with mock or local cameras.
- Raspberry Pi / SBC appliance mode with GStreamer, GPIO, and optional AI
  acceleration.
- Service-only packaging for Debian and headless validation.

## Development Setup

Install Flutter, CMake, Qt 6, GStreamer, and ONNX Runtime. On macOS the local
helper configures the expected Homebrew paths:

```bash
source scripts/dev-env.sh
flutter pub get
scripts/build-service.sh
```

The service can be smoke-tested without appliance hardware:

```bash
scripts/smoke-backend.sh
```

## Quality Checks

Run the checks that match the files you changed:

```bash
flutter analyze
flutter test
cmake --build service/build -j4
ctest --test-dir service/build --output-on-failure
```

For shell or packaging changes, also run:

```bash
bash -n scripts/*.sh
bash -n os/*.sh
bash -n packaging/scripts/*.sh
```

## Native Service Guidelines

- Keep hardware-specific behavior behind capability checks or platform
  selection. Do not assume every install is a Raspberry Pi.
- Prefer mock-safe defaults for desktop development.
- Keep config writes atomic and migration-aware.
- Keep `main.cpp` as wiring code; put reusable runtime logic in focused service
  modules.
- Do not add object labels, GPIO pins, camera devices, or preview transports as
  product-wide hardcoded assumptions.

## Flutter Guidelines

- Use the `KioskServiceClient` abstraction instead of binding screens directly
  to a socket transport.
- Keep controls capability-driven: hide or disable GPIO, DMA-BUF, IOSurface, or
  camera options when the backend reports them unavailable.
- Preserve kiosk ergonomics: large touch targets, stable layout, readable Thai
  labels, and no layout shift during live preview.
- Avoid sending raw video frames through Dart. Use the active native texture or
  shared-memory preview path.

## Packaging And Appliance Work

Package modes are selected with `BEENUT_KIOSK_MODE`:

- `flutter-pi`: Raspberry Pi appliance target.
- `linux`: desktop Linux runner target.
- `service`: headless backend package target.

Useful commands:

```bash
BEENUT_KIOSK_MODE=service ALLOW_MISSING_ARTIFACTS=1 scripts/assemble-package.sh
os/build-beenut-image.sh --metadata-only
```

When changing packaging, update `docs/PHASE_EXECUTION_CHECKLIST.md` if an
implementation status changes, and `docs/PHASE_COMPLETION_CHECKLIST.md` if the
release evidence requirements change.

## Pull Request Checklist

- The change has a narrow, explainable scope.
- Relevant tests or smoke checks pass.
- User-facing behavior is documented when it changes.
- Hardware features degrade cleanly on unsupported platforms.
- Generated artifacts, local caches, and `.DS_Store` files are not committed.
