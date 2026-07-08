# BeeNut Appliance OS

This directory is the starting point for building a Raspberry Pi appliance image
that boots directly into BeeNut.

The first supported target is Raspberry Pi OS Lite 64-bit with the BeeNut `.deb`
installed into the root filesystem. Full image generation still depends on a
Pi image builder such as `pi-gen` or `debos`; this repo keeps the BeeNut-specific
configuration, overlays, and release metadata in one place.

## Quick Shape

```text
os/
├── build-beenut-image.sh
├── config/
│   ├── arm64.env
│   ├── rpi4.env
│   ├── rpi5.env
│   └── x86_64.env
├── beenut.yaml
├── beenut-arm64.yaml
├── beenut-x86_64.yaml
└── overlays/
    └── etc/
        ├── issue
        ├── motd
        └── systemd/system/getty@tty1.service.d/beenut-branding.conf
```

## Usage

```bash
BEENUT_VERSION=0.3.0 \
BEENUT_DEB=build/deb/beenut_0.3.0_arm64.deb \
BEENUT_BOARD=rpi5 \
os/build-beenut-image.sh --metadata-only
```

`--metadata-only` is useful in CI and on development machines. It verifies the
package artifact and writes release metadata without requiring privileged image
build tooling. The manifest also records every OS overlay file with a checksum,
so appliance branding and first-run defaults are auditable before an image is
flashed.

To stage BeeNut files into a root filesystem directory for `pi-gen`, `debos`, or
manual inspection:

```bash
BEENUT_VERSION=0.3.0 \
BEENUT_DEB=build/deb/beenut_0.3.0_arm64.deb \
BEENUT_BOARD=rpi5 \
os/build-beenut-image.sh --rootfs-dir build/rootfs
```

This copies `os/overlays/`, the `.deb`, and `manifest.json` into the rootfs
without requiring mount privileges.

Future full image builds should install the staged `.deb`, enable `beenut-first-boot`,
`beenut-service`, and `beenut-kiosk`, then emit:

```text
build/os/beenut-os-rpi-arm64-VERSION.img.xz
build/os/beenut-os-rpi-arm64-VERSION.sha256
build/os/manifest.json
```
