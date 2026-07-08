# BeeNut Installer Setup

BeeNut packages are architecture-specific because they contain native binaries.
Build/publish separate `.deb` files for `arm64` and `amd64`, then let the
bootstrap installer detect the target architecture and download the matching
asset.

## Interactive install

The Linux bootstrap installer installs the `.deb`, then opens `beenut-setup` on
`/dev/tty` when a terminal is available:

```bash
curl -fsSL https://raw.githubusercontent.com/mengsokool/app.beenut/master/scripts/install-linux.sh | sudo bash
```

`beenut-setup` detects:

- CPU/package architecture such as `arm64`, `amd64`, or `armhf`;
- Raspberry Pi hardware;
- display manager or desktop environment;
- systemd default target;
- camera/display device presence;
- GRUB and Plymouth availability.
- profile-specific runtime dependencies such as `cage` and `flutter-pi`;
- DRM/KMS device nodes used by Linux appliance kiosk mode.

## Install modes

| Profile | Behavior |
| --- | --- |
| `desktop` | Normal app install. Does not take over boot. |
| `appliance-linux` | Generic Linux kiosk. Enables BeeNut services and applies appliance hardening. |
| `appliance-pi` | Raspberry Pi kiosk. Uses the Pi/flutter-pi path and applies appliance hardening. |
| `dev-service` | Backend service only for development or diagnostics. |

## Appliance hardening

When `appliance-linux` or `appliance-pi` is selected interactively, the Linux
adapter may:

- set the default systemd target to `multi-user.target`;
- disable and stop display managers such as GDM, SDDM, LightDM, and LXDM;
- disable the primary TTY login prompt;
- enable `beenut-service.service` and `beenut-kiosk.service`;
- rewrite `/etc/default/grub` for silent BeeNut boot and run `update-grub`;
- install a BeeNut Plymouth splash theme when Plymouth is available;
- update Raspberry Pi `/boot/firmware` camera/display/GPIO boot settings.

Files overwritten by the hardening path are backed up under
`/etc/beenut/backups/` on first write.

Before hardening, setup installs missing profile dependencies through `apt`
where possible. A desktop-profile `.deb` can therefore be promoted to
`appliance-linux` later; setup installs `cage` before enabling the kiosk
service. The Linux appliance path also preflights the Flutter Linux bundle and
warns when `/dev/dri/card0` or render nodes are missing.

Preview changes before applying:

```bash
sudo beenut-setup --profile appliance-linux --dry-run
```

Recover a device or VM that was moved into appliance mode:

```bash
sudo beenut-setup --recover-desktop
sudo beenut-recover-desktop
```

Recovery disables BeeNut kiosk services, resets failed units, sets the default
systemd target back to `graphical.target`, and re-enables the first available
display manager.

## Package maintainer scripts

Raw `.deb` installation and upgrades must stay non-interactive. The package
`postinst` therefore runs setup without appliance hardening:

```bash
beenut-setup --non-interactive --no-appliance-hardening --profile <package-profile>
```

This keeps `apt install` and `apt upgrade` safe. Full kiosk takeover happens
only when a user explicitly runs `sudo beenut-setup` or when the bootstrap
installer is given an explicit kiosk profile.

## Bootstrap behavior

`scripts/install-linux.sh` is safe to rerun. It uses a lock file to prevent two
installs from racing, repairs interrupted `dpkg`/`apt` state, downloads the
architecture-matching `.deb`, verifies `checksums.sha256`, installs or upgrades
the package with `apt`, then runs setup. Non-interactive installs without an
explicit `BEENUT_PROFILE` stay in the safe package/default profile and do not
apply appliance hardening.
