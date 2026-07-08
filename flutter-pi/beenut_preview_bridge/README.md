# Beenut flutter-pi preview bridge

This is the production Raspberry Pi preview bridge target for BeeNut.

It is intentionally separate from Flutter's Linux/GTK runner. `flutter-pi`
does not execute `linux/runner/*`, so the GTK `FlPixelBufferTexture` bridge
cannot be used for production DRM/GBM/EGL kiosk mode.

## Transport

The backend will expose a Unix socket and send one DMA-BUF frame per message:

- payload: `BeenutDmabufFrame`
- file descriptors: DMA-BUF fds via `SCM_RIGHTS`
- channel used by Dart: `beenut/preview_texture`

The plugin returns a Flutter external texture id from `create`, then imports
each received DMA-BUF as:

```text
DMA-BUF fd -> EGLImageKHR(EGL_LINUX_DMA_BUF_EXT) -> GL texture -> Flutter Texture
```

## Status

This directory contains the flutter-pi plugin source and install patch helper.
It must be built inside a flutter-pi source checkout because flutter-pi's
texture registry/plugin headers are internal to that project.

The backend can now publish DMA-BUF frames when `camera.preview_transport` is
`dmabuf_egl` and the GStreamer preview buffer is backed by DMA-BUF memory. If
the active camera pipeline falls back to ordinary CPU memory, use `shm_nv12`
or adjust the Pi camera pipeline to preserve `memory:DMABuf` through appsink.

## Install into flutter-pi source

```bash
flutter-pi/beenut_preview_bridge/install-flutter-pi-bridge.sh /path/to/flutter-pi
cd /path/to/flutter-pi
cmake -S . -B build
cmake --build build -j "$(nproc)"
sudo cmake --install build
```
