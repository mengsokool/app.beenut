#!/usr/bin/env python3
"""BeeNut setup CLI with platform adapters.

The CLI is intentionally split into a portable profile/detection layer and
small platform adapters. Linux/systemd is the first supported installer target;
future Windows support should add a new adapter without changing profile names.
"""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


APP_ROOT = Path(os.environ.get("BEENUT_APP_ROOT", "/opt/beenut"))
ETC_ROOT = Path(os.environ.get("BEENUT_ETC_ROOT", "/etc/beenut"))
STATE_ROOT = Path(os.environ.get("BEENUT_STATE_ROOT", "/var/lib/beenut"))
LOG_ROOT = Path(os.environ.get("BEENUT_LOG_ROOT", "/var/log/beenut"))
SYSTEMD_ROOT = Path(os.environ.get("BEENUT_SYSTEMD_ROOT", "/etc/systemd/system"))
RECOVERY_COMMAND_PATH = Path(os.environ.get("BEENUT_RECOVERY_COMMAND_PATH", "/usr/bin/beenut-recover-desktop"))


@dataclass(frozen=True)
class Profile:
    key: str
    title: str
    description: str
    kiosk_mode: str
    service_enabled: bool
    kiosk_enabled: bool
    appliance_hardening: bool = False


PROFILES = {
    "appliance-pi": Profile(
        key="appliance-pi",
        title="Raspberry Pi appliance kiosk",
        description="Boots directly into the flutter-pi kiosk and starts beenutd.",
        kiosk_mode="flutter-pi",
        service_enabled=True,
        kiosk_enabled=True,
        appliance_hardening=True,
    ),
    "appliance-linux": Profile(
        key="appliance-linux",
        title="Linux appliance kiosk",
        description="Boots through Cage/systemd; requires a working DRM/KMS display stack.",
        kiosk_mode="linux",
        service_enabled=True,
        kiosk_enabled=True,
        appliance_hardening=True,
    ),
    "desktop": Profile(
        key="desktop",
        title="Desktop app",
        description="Installs the app and service files without taking over boot.",
        kiosk_mode="linux",
        service_enabled=False,
        kiosk_enabled=False,
    ),
    "dev-service": Profile(
        key="dev-service",
        title="Service only",
        description="Runs beenutd for diagnostics or development without kiosk UI.",
        kiosk_mode="service",
        service_enabled=True,
        kiosk_enabled=False,
    ),
}


def run(
    command: list[str],
    *,
    check: bool = True,
    quiet: bool = False,
    allow_missing: bool = False,
) -> subprocess.CompletedProcess[str] | None:
    if allow_missing and shutil.which(command[0]) is None:
        return None
    stdout = subprocess.DEVNULL if quiet else None
    stderr = subprocess.DEVNULL if quiet else None
    return subprocess.run(command, check=check, text=True, stdout=stdout, stderr=stderr)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def write_text(path: Path, value: str, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8")
    path.chmod(mode)


def command_output(command: list[str]) -> str:
    try:
        completed = subprocess.run(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except OSError:
        return ""
    if completed.returncode != 0:
        return ""
    return completed.stdout.strip()


def has_command(command: str) -> bool:
    return shutil.which(command) is not None


def package_status(package: str) -> str:
    if not has_command("dpkg-query"):
        return ""
    try:
        completed = subprocess.run(
            ["dpkg-query", "-W", "-f=${Status}", package],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
    except OSError:
        return ""
    if completed.returncode != 0:
        return ""
    return completed.stdout


def normalize_arch(machine: str) -> str:
    dpkg_arch = command_output(["dpkg", "--print-architecture"])
    if dpkg_arch in ("arm64", "amd64", "armhf"):
        return dpkg_arch
    if machine in ("aarch64", "arm64"):
        return "arm64"
    if machine in ("x86_64", "amd64"):
        return "amd64"
    if machine.startswith("armv7") or machine == "armhf":
        return "armhf"
    return machine


def active_systemd_units(names: tuple[str, ...]) -> str:
    active = []
    if shutil.which("systemctl") is None:
        return ""
    for name in names:
        completed = subprocess.run(
            ["systemctl", "is-active", "--quiet", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if completed.returncode == 0:
            active.append(name)
    return ",".join(active)


def detect_desktop_environment() -> str:
    env_values = [
        os.environ.get("XDG_CURRENT_DESKTOP", ""),
        os.environ.get("DESKTOP_SESSION", ""),
        os.environ.get("GDMSESSION", ""),
    ]
    value = "/".join(item for item in env_values if item)
    if value:
        return value
    active_dms = active_systemd_units(("display-manager.service", "gdm.service", "gdm3.service", "sddm.service", "lightdm.service", "lxdm.service"))
    if active_dms:
        return f"display-manager:{active_dms}"
    return ""


def detect() -> dict[str, str | bool]:
    system = platform.system().lower() or "unknown"
    machine = platform.machine().lower() or "unknown"
    os_release = {}
    release_path = Path("/etc/os-release")
    if release_path.exists():
        for line in read_text(release_path).splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                os_release[key] = value.strip('"')

    pi_model = read_text(Path("/proc/device-tree/model"))
    if not pi_model:
        pi_model = read_text(Path("/sys/firmware/devicetree/base/model"))

    arch = normalize_arch(machine)
    desktop_environment = detect_desktop_environment()
    default_target = command_output(["systemctl", "get-default"]) if shutil.which("systemctl") else ""
    virtualization = command_output(["systemd-detect-virt"]) if shutil.which("systemd-detect-virt") else ""

    return {
        "system": system,
        "machine": machine,
        "arch": arch,
        "os_id": os_release.get("ID", ""),
        "os_name": os_release.get("PRETTY_NAME", ""),
        "is_raspberry_pi": "raspberry pi" in pi_model.lower(),
        "raspberry_pi_model": pi_model,
        "has_systemd": Path("/run/systemd/system").exists() and shutil.which("systemctl") is not None,
        "has_camera": any(Path("/dev").glob("video*")),
        "has_display": bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY") or Path("/dev/dri").exists()),
        "desktop_environment": desktop_environment,
        "virtualization": virtualization,
        "has_desktop_environment": bool(desktop_environment or active_systemd_units(("display-manager.service",))),
        "default_systemd_target": default_target,
        "has_grub": Path("/etc/default/grub").exists() or shutil.which("update-grub") is not None,
        "has_plymouth": shutil.which("plymouth-set-default-theme") is not None or Path("/usr/share/plymouth/themes").exists(),
        "has_apt": has_command("apt-get"),
        "has_dpkg": has_command("dpkg-query"),
        "has_cage": has_command("cage") or Path("/usr/bin/cage").exists(),
        "has_flutter_pi": has_command("flutter-pi"),
        "has_drm": Path("/dev/dri/card0").exists(),
        "has_render_node": any(Path("/dev/dri").glob("renderD*")) if Path("/dev/dri").exists() else False,
        "has_linux_bundle": (APP_ROOT / "flutter-linux/beenut").exists(),
        "has_flutter_pi_bundle": (APP_ROOT / "flutter-pi/kernel_blob.bin").exists(),
    }


def recommended_profile(facts: dict[str, str | bool]) -> str:
    if facts["system"] == "linux" and facts["is_raspberry_pi"]:
        return "appliance-pi"
    if facts["system"] == "linux":
        return "appliance-linux"
    return "desktop"


def package_profile_default() -> str:
    value = read_text(APP_ROOT / "package-profile")
    return value if value in PROFILES else ""


def choose_profile(facts: dict[str, str | bool]) -> str:
    default = package_profile_default() or recommended_profile(facts)
    choices = list(PROFILES.values())
    print("BeeNut setup")
    print(f"Detected: {facts['os_name'] or facts['system']} / {facts['arch']} ({facts['machine']})")
    if facts["raspberry_pi_model"]:
        print(f"Hardware: {facts['raspberry_pi_model']}")
    if facts["desktop_environment"]:
        print(f"Desktop: {facts['desktop_environment']}")
    elif facts["has_desktop_environment"]:
        print("Desktop: display manager detected")
    else:
        print("Desktop: not detected")
    if facts["default_systemd_target"]:
        print(f"Boot target: {facts['default_systemd_target']}")
    if facts["virtualization"]:
        print(f"Virtualization: {facts['virtualization']}")
    print("")
    for index, profile in enumerate(choices, start=1):
        marker = " (recommended)" if profile.key == default else ""
        print(f"{index}. {profile.title}{marker}")
        print(f"   {profile.description}")
        if profile.appliance_hardening:
            print("   Will take over boot, disable desktop login, and apply appliance boot settings.")
            if facts["virtualization"] and profile.kiosk_mode == "linux":
                print("   VM note: Cage kiosk mode needs DRM/KMS support; choose Desktop app if the VM shows a black screen.")
    print("")
    answer = input(f"Select install mode [default: {default}]: ").strip()
    if not answer:
        return default
    if answer in PROFILES:
        return answer
    try:
        selected = choices[int(answer) - 1]
    except (ValueError, IndexError):
        raise SystemExit(f"Invalid profile selection: {answer}")
    return selected.key


class BaseAdapter:
    def __init__(self, facts: dict[str, str | bool], dry_run: bool = False, apply_appliance_hardening: bool = True) -> None:
        self.facts = facts
        self.dry_run = dry_run
        self.apply_appliance_hardening = apply_appliance_hardening

    def apply(self, profile: Profile) -> None:
        raise NotImplementedError

    def step(self, message: str) -> None:
        print(message)

    def run(self, command: list[str], *, check: bool = True, quiet: bool = False, allow_missing: bool = False) -> None:
        display = " ".join(command)
        if self.dry_run:
            self.step(f"dry-run: {display}")
            return
        result = run(command, check=check, quiet=quiet, allow_missing=allow_missing)
        if result is None and not quiet:
            self.step(f"skipped missing command: {command[0]}")


class UnsupportedAdapter(BaseAdapter):
    def apply(self, profile: Profile) -> None:
        self.step(f"Profile '{profile.key}' is valid, but {self.facts['system']} setup is not implemented yet.")
        self.step("The profile layer is portable; add a platform adapter for this OS to apply it.")


class LinuxAdapter(BaseAdapter):
    groups = ("gpio", "video", "render", "input", "dialout")
    display_manager_units = (
        "display-manager.service",
        "gdm.service",
        "gdm3.service",
        "sddm.service",
        "lightdm.service",
        "lxdm.service",
    )
    recovery_units = (
        "beenut-kiosk.service",
        "beenut-kiosk-linux.service",
        "beenut-kiosk-flutter-pi.service",
        "beenut-service.service",
        "beenut-first-boot.service",
    )

    def apply(self, profile: Profile) -> None:
        if os.geteuid() != 0 and not self.dry_run:
            raise SystemExit("Run with sudo/root to apply Linux setup.")
        self.write_recovery_command()
        self.ensure_profile_dependencies(profile)
        self.ensure_user()
        self.ensure_directories()
        self.ensure_sudoers()
        self.ensure_config(profile)
        self.install_systemd_units(profile)
        self.configure_kiosk_renderer(profile)
        self.write_install_state(profile)
        if profile.appliance_hardening and self.apply_appliance_hardening:
            self.preflight_appliance(profile)
            self.apply_linux_appliance_hardening(profile)
        elif profile.appliance_hardening:
            self.step("Appliance hardening skipped for package post-install. Run 'sudo beenut-setup' to take over boot.")
        if profile.key == "desktop":
            self.restore_desktop_boot()
        self.apply_systemd_state(profile)
        self.step(f"BeeNut setup applied: {profile.key}")

    def package_installed(self, package: str) -> bool:
        return "install ok installed" in package_status(package)

    def ensure_apt_packages(self, packages: list[str]) -> None:
        if not self.facts["has_dpkg"]:
            raise SystemExit(f"Cannot check required packages because dpkg-query is not available: {', '.join(packages)}")
        missing = [package for package in packages if not self.package_installed(package)]
        if not missing:
            return
        if not self.facts["has_apt"]:
            raise SystemExit(f"Missing required packages and apt-get is not available: {', '.join(missing)}")
        self.step(f"Installing required packages: {', '.join(missing)}")
        env_prefix = ["env", "DEBIAN_FRONTEND=noninteractive"]
        self.run([*env_prefix, "apt-get", "update"], check=False)
        self.run([*env_prefix, "apt-get", "install", "-y", *missing])

    def ensure_profile_dependencies(self, profile: Profile) -> None:
        if self.facts["system"] != "linux":
            return
        packages: list[str] = []
        if profile.key == "appliance-linux":
            packages.extend(["cage", "plymouth", "plymouth-themes"])
        elif profile.key == "appliance-pi":
            if not self.facts["is_raspberry_pi"]:
                self.step("Warning: appliance-pi selected on non-Raspberry Pi hardware.")
            if not self.facts["has_flutter_pi"]:
                packages.extend(["flutter-pi"])
            packages.extend(["plymouth", "plymouth-themes"])
        if packages:
            self.ensure_apt_packages(packages)
            if self.dry_run:
                if profile.key == "appliance-linux":
                    self.facts["has_cage"] = True
                elif profile.key == "appliance-pi":
                    self.facts["has_flutter_pi"] = True
            else:
                self.facts.update(detect())

    def preflight_appliance(self, profile: Profile) -> None:
        if profile.key == "appliance-linux":
            if not self.facts["has_cage"]:
                raise SystemExit("Cage is required for appliance-linux but was not found after dependency installation.")
            if not self.facts["has_linux_bundle"]:
                raise SystemExit(f"Flutter Linux bundle was not found at {APP_ROOT / 'flutter-linux/beenut'}. Reinstall the BeeNut .deb.")
            if not self.facts["has_drm"]:
                self.step("Warning: /dev/dri/card0 was not detected. Cage kiosk may not be able to open a display.")
            if not self.facts["has_render_node"]:
                self.step("Warning: no /dev/dri/renderD* node was detected. GPU rendering may fail.")
            if self.facts["virtualization"]:
                self.step("VM note: appliance-linux depends on DRM/KMS support from the VM GPU driver.")
        elif profile.key == "appliance-pi":
            if not self.facts["has_flutter_pi"]:
                raise SystemExit("flutter-pi is required for appliance-pi but was not found after dependency installation.")
            if not self.facts["has_flutter_pi_bundle"]:
                raise SystemExit(f"flutter-pi asset bundle was not found at {APP_ROOT / 'flutter-pi/kernel_blob.bin'}. Reinstall the BeeNut .deb.")

    def write_recovery_command(self) -> None:
        content = """#!/usr/bin/env sh
set -eu

if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now beenut-kiosk.service beenut-kiosk-linux.service beenut-kiosk-flutter-pi.service >/dev/null 2>&1 || true
  systemctl disable --now beenut-service.service beenut-first-boot.service >/dev/null 2>&1 || true
  systemctl reset-failed beenut-kiosk.service beenut-kiosk-linux.service beenut-kiosk-flutter-pi.service beenut-service.service >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/system.conf.d/beenut-quiet-boot.conf
  rm -f /etc/initramfs-tools/conf.d/beenut-splash
  if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u >/dev/null 2>&1 || true
  fi
  systemctl set-default graphical.target >/dev/null 2>&1 || true
  for unit in lightdm.service gdm.service gdm3.service sddm.service lxdm.service display-manager.service; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
      systemctl enable --now "$unit" >/dev/null 2>&1 || true
      break
    fi
  done
fi

echo "BeeNut desktop recovery applied."
"""
        if self.dry_run:
            self.step(f"dry-run: write {RECOVERY_COMMAND_PATH}")
            return
        write_text(RECOVERY_COMMAND_PATH, content, 0o755)

    def recover_desktop(self) -> None:
        self.step("Recovering desktop boot...")
        self.write_recovery_command()
        if not self.facts["has_systemd"]:
            self.step("systemd is not running; recovery command was written only.")
            return
        for unit in self.recovery_units:
            self.run(["systemctl", "disable", "--now", unit], check=False, quiet=True)
        self.run(["systemctl", "reset-failed", *self.recovery_units], check=False, quiet=True)
        self.remove_systemd_quiet_boot()
        self.restore_desktop_boot()
        self.step("BeeNut desktop recovery applied.")

    def remove_systemd_quiet_boot(self) -> None:
        drop_in = SYSTEMD_ROOT / "system.conf.d/beenut-quiet-boot.conf"
        if self.dry_run:
            self.step(f"dry-run: remove {drop_in}")
            return
        if drop_in.exists():
            drop_in.unlink()
        initramfs_splash = Path("/etc/initramfs-tools/conf.d/beenut-splash")
        if initramfs_splash.exists():
            initramfs_splash.unlink()
        self.run(["update-initramfs", "-u"], check=False, quiet=True, allow_missing=True)

    def restore_desktop_boot(self) -> None:
        if not self.facts["has_systemd"]:
            return
        self.run(["systemctl", "set-default", "graphical.target"], check=False, quiet=True)
        enabled = False
        for unit in self.display_manager_units:
            completed = subprocess.run(
                ["systemctl", "list-unit-files", unit],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if completed.returncode == 0:
                self.run(["systemctl", "enable", "--now", unit], check=False, quiet=True)
                enabled = True
                break
        if not enabled:
            self.step("No known display manager was found to re-enable.")

    def ensure_user(self) -> None:
        if self.dry_run:
            self.step("dry-run: ensure system user beenut and hardware groups")
            return
        user_exists = subprocess.run(
            ["id", "beenut"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
        if not user_exists:
            self.run(["useradd", "--system", "--home", str(STATE_ROOT), "--shell", "/usr/sbin/nologin", "beenut"])
        for group in self.groups:
            if subprocess.run(["getent", "group", group], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                self.run(["usermod", "-aG", group, "beenut"], check=False, quiet=True)

    def ensure_directories(self) -> None:
        for path in (ETC_ROOT, STATE_ROOT, STATE_ROOT / "models", LOG_ROOT):
            if self.dry_run:
                self.step(f"dry-run: create {path}")
            else:
                path.mkdir(parents=True, exist_ok=True)
                shutil.chown(path, user="beenut", group="beenut")

    def ensure_sudoers(self) -> None:
        content = (
            "beenut ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff, /bin/systemctl poweroff, "
            "/usr/sbin/poweroff, /sbin/poweroff, /usr/bin/systemctl reboot, /bin/systemctl reboot, "
            "/usr/sbin/reboot, /sbin/reboot, /usr/sbin/shutdown, /sbin/shutdown\n"
        )
        if self.dry_run:
            self.step("dry-run: write /etc/sudoers.d/beenut")
            return
        write_text(Path("/etc/sudoers.d/beenut"), content, 0o440)

    def ensure_config(self, profile: Profile) -> None:
        target = ETC_ROOT / "config.json"
        source = APP_ROOT / "config/default.json"
        if self.dry_run:
            self.step(f"dry-run: ensure {target} from {source}")
            return
        if not target.exists() and source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        if target.exists():
            shutil.chown(target, user="beenut", group="beenut")
            target.chmod(0o640)

    def install_systemd_units(self, profile: Profile) -> None:
        source_dir = APP_ROOT / "systemd"
        unit_names = (
            "beenut-service.service",
            "beenut-first-boot.service",
            "beenut-kiosk-flutter-pi.service",
            "beenut-kiosk-linux.service",
        )
        if self.dry_run:
            self.step(f"dry-run: install systemd units for {profile.key}")
            return
        SYSTEMD_ROOT.mkdir(parents=True, exist_ok=True)
        for unit in unit_names:
            source = source_dir / unit
            if source.exists():
                shutil.copy2(source, SYSTEMD_ROOT / unit)
        kiosk_link = SYSTEMD_ROOT / "beenut-kiosk.service"
        if kiosk_link.exists() or kiosk_link.is_symlink():
            kiosk_link.unlink()
        if profile.kiosk_enabled:
            target = "beenut-kiosk-flutter-pi.service" if profile.kiosk_mode == "flutter-pi" else "beenut-kiosk-linux.service"
            shutil.copy2(SYSTEMD_ROOT / target, kiosk_link)

    def configure_kiosk_renderer(self, profile: Profile) -> None:
        drop_in = SYSTEMD_ROOT / "beenut-kiosk.service.d/beenut-vm-renderer.conf"
        if profile.key != "appliance-linux" or not self.facts["virtualization"]:
            if self.dry_run:
                self.step(f"dry-run: remove VM renderer override {drop_in} if present")
            elif drop_in.exists():
                drop_in.unlink()
            return
        content = "\n".join(
            [
                "[Service]",
                "Environment=GDK_BACKEND=wayland",
                "Environment=WLR_NO_HARDWARE_CURSORS=1",
                "Environment=WLR_RENDERER=pixman",
                "",
            ]
        )
        if self.dry_run:
            self.step(f"dry-run: write VM renderer override {drop_in}")
            return
        self.step("VM detected; using software renderer fallback for Cage kiosk.")
        write_text(drop_in, content, 0o644)

    def write_install_state(self, profile: Profile) -> None:
        state = (
            f"profile={profile.key}\n"
            f"kiosk_mode={profile.kiosk_mode}\n"
            f"service_enabled={'1' if profile.service_enabled else '0'}\n"
            f"kiosk_enabled={'1' if profile.kiosk_enabled else '0'}\n"
            f"appliance_hardening={'1' if profile.appliance_hardening and self.apply_appliance_hardening else '0'}\n"
        )
        if self.dry_run:
            self.step("dry-run: write /etc/beenut/install-profile.conf")
            return
        write_text(ETC_ROOT / "install-profile.conf", state, 0o644)

    def backup_file(self, path: Path) -> Path | None:
        if not path.exists():
            return None
        backup_dir = ETC_ROOT / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = backup_dir / f"{path.name}.before-beenut"
        if not backup_path.exists():
            shutil.copy2(path, backup_path)
        return backup_path

    def apply_linux_appliance_hardening(self, profile: Profile) -> None:
        self.step("Applying Linux appliance hardening...")
        self.configure_boot_target()
        self.disable_desktop_managers()
        self.disable_login_prompt()
        self.configure_systemd_quiet_boot()
        self.configure_grub()
        self.configure_plymouth()
        if self.facts["is_raspberry_pi"]:
            self.configure_raspberry_pi_boot()

    def configure_boot_target(self) -> None:
        if not self.facts["has_systemd"]:
            self.step("systemd is not running; boot target changes deferred.")
            return
        self.run(["systemctl", "set-default", "multi-user.target"], check=False, quiet=True)

    def disable_desktop_managers(self) -> None:
        if not self.facts["has_systemd"]:
            return
        for unit in self.display_manager_units:
            self.run(["systemctl", "disable", unit], check=False, quiet=True)
            self.run(["systemctl", "stop", unit], check=False, quiet=True)

    def disable_login_prompt(self) -> None:
        if not self.facts["has_systemd"]:
            return
        self.run(["systemctl", "disable", "getty@tty1.service"], check=False, quiet=True)
        drop_in = SYSTEMD_ROOT / "getty@tty1.service.d/beenut-branding.conf"
        if self.dry_run:
            self.step(f"dry-run: write {drop_in}")
            return
        write_text(drop_in, "[Service]\nTTYVTDisallocate=yes\n", 0o644)

    def configure_systemd_quiet_boot(self) -> None:
        drop_in = SYSTEMD_ROOT / "system.conf.d/beenut-quiet-boot.conf"
        content = "\n".join(
            [
                "[Manager]",
                "ShowStatus=no",
                "StatusUnitFormat=name",
                "",
            ]
        )
        if self.dry_run:
            self.step(f"dry-run: write {drop_in}")
            return
        write_text(drop_in, content, 0o644)

    def configure_grub(self) -> None:
        grub_path = Path("/etc/default/grub")
        if not self.facts["has_grub"] and not grub_path.exists() and shutil.which("update-grub") is None:
            self.step("GRUB not detected; boot menu changes skipped.")
            return
        quiet_cmdline = (
            "quiet splash loglevel=0 rd.systemd.show_status=0 systemd.show_status=0 "
            "udev.log_level=3 rd.udev.log_level=3 vt.global_cursor_default=0 plymouth.enable=1"
        )
        content = "\n".join(
            [
                "GRUB_DEFAULT=0",
                "GRUB_TIMEOUT=0",
                "GRUB_RECORDFAIL_TIMEOUT=0",
                "GRUB_HIDDEN_TIMEOUT=0",
                "GRUB_HIDDEN_TIMEOUT_QUIET=true",
                'GRUB_DISTRIBUTOR="BeeNut"',
                'GRUB_GFXMODE=auto',
                'GRUB_GFXPAYLOAD_LINUX=keep',
                f'GRUB_CMDLINE_LINUX_DEFAULT="{quiet_cmdline}"',
                'GRUB_CMDLINE_LINUX=""',
                "",
            ]
        )
        if self.dry_run:
            self.step("dry-run: backup and write /etc/default/grub for silent BeeNut boot")
        else:
            self.backup_file(grub_path)
            write_text(grub_path, content, 0o644)
        self.run(["update-grub"], check=False, quiet=True, allow_missing=True)

    def configure_plymouth(self) -> None:
        theme_root = Path("/usr/share/plymouth/themes/beenut")
        if self.dry_run:
            self.step("dry-run: install BeeNut Plymouth theme if Plymouth is available")
            return
        if not self.facts["has_plymouth"]:
            self.step("Plymouth not detected; boot splash theme skipped.")
            return
        theme_root.mkdir(parents=True, exist_ok=True)
        logo_source = APP_ROOT / "branding/logo.png"
        if not logo_source.exists():
            logo_source = APP_ROOT / "flutter-linux/data/flutter_assets/assets/images/logo.png"
        logo_target = theme_root / "logo.png"
        if logo_source.exists():
            shutil.copy2(logo_source, logo_target)
        else:
            self.step("BeeNut logo not found; Plymouth theme skipped.")
            return
        initramfs_splash = Path("/etc/initramfs-tools/conf.d/beenut-splash")
        if initramfs_splash.parent.exists():
            write_text(initramfs_splash, "FRAMEBUFFER=y\n", 0o644)
        write_text(
            theme_root / "beenut.plymouth",
            "\n".join(
                [
                    "[Plymouth Theme]",
                    "Name=BeeNut",
                    "Description=BeeNut appliance boot splash",
                    "ModuleName=script",
                    "",
                    "[script]",
                    "ImageDir=/usr/share/plymouth/themes/beenut",
                    "ScriptFile=/usr/share/plymouth/themes/beenut/beenut.script",
                    "",
                ]
            ),
            0o644,
        )
        write_text(
            theme_root / "beenut.script",
            "\n".join(
                [
                    'screen_width = Window.GetWidth();',
                    'screen_height = Window.GetHeight();',
                    'Window.SetBackgroundTopColor(0.0, 0.0, 0.0);',
                    'Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);',
                    'raw_logo = Image("logo.png");',
                    'logo_width = raw_logo.GetWidth();',
                    'logo_height = raw_logo.GetHeight();',
                    'max_logo = screen_height * 0.30;',
                    'max_logo_by_width = screen_width * 0.24;',
                    'if (max_logo_by_width < max_logo) max_logo = max_logo_by_width;',
                    'if (logo_width > max_logo) {',
                    '  logo_height = logo_height * max_logo / logo_width;',
                    '  logo_width = max_logo;',
                    '}',
                    'if (logo_height > max_logo) {',
                    '  logo_width = logo_width * max_logo / logo_height;',
                    '  logo_height = max_logo;',
                    '}',
                    'logo = raw_logo.Scale(logo_width, logo_height);',
                    'sprite = Sprite(logo);',
                    'sprite.SetX(screen_width / 2 - logo.GetWidth() / 2);',
                    'sprite.SetY(screen_height / 2 - logo.GetHeight() / 2);',
                    'sprite.SetOpacity(0.0);',
                    'dot = Image.Text("o", 0.98, 0.76, 0.16);',
                    'dot1 = Sprite(dot);',
                    'dot2 = Sprite(dot);',
                    'dot3 = Sprite(dot);',
                    'dot1.SetOpacity(0.0);',
                    'dot2.SetOpacity(0.0);',
                    'dot3.SetOpacity(0.0);',
                    'global.start_time = Plymouth.GetTime();',
                    'global.quit_time = 0;',
                    '',
                    'fun place_dot(dot_sprite, x_offset, y_offset, opacity) {',
                    '  radius = screen_height * 0.045;',
                    '  if (screen_width * 0.035 < radius) radius = screen_width * 0.035;',
                    '  dot_sprite.SetX(screen_width / 2 + x_offset * radius - dot.GetWidth() / 2);',
                    '  dot_sprite.SetY(screen_height / 2 + y_offset * radius - dot.GetHeight() / 2);',
                    '  dot_sprite.SetOpacity(opacity);',
                    '}',
                    '',
                    'fun place_boot_dot(dot_sprite, x_index, opacity) {',
                    '  spacing = dot.GetWidth() * 2.1;',
                    '  y = screen_height / 2 + logo.GetHeight() / 2 + screen_height * 0.055;',
                    '  dot_sprite.SetX(screen_width / 2 + x_index * spacing - dot.GetWidth() / 2);',
                    '  dot_sprite.SetY(y - dot.GetHeight() / 2);',
                    '  dot_sprite.SetOpacity(opacity);',
                    '}',
                    '',
                    'fun refresh_callback() {',
                    '  mode = Plymouth.GetMode();',
                    '  now = Plymouth.GetTime();',
                    '  if (mode == "shutdown" || mode == "reboot") {',
                    '    sprite.SetOpacity(0.0);',
                    '    phase = now * 2.8;',
                    '    while (phase >= 3.0) phase = phase - 3.0;',
                    '    opacity1 = 1.0;',
                    '    opacity2 = 0.62;',
                    '    opacity3 = 0.28;',
                    '    if (phase >= 1.0) {',
                    '      if (phase < 2.0) {',
                    '        opacity1 = 0.28;',
                    '        opacity2 = 1.0;',
                    '        opacity3 = 0.62;',
                    '      }',
                    '    }',
                    '    if (phase >= 2.0) {',
                    '      opacity1 = 0.62;',
                    '      opacity2 = 0.28;',
                    '      opacity3 = 1.0;',
                    '    }',
                    '    place_dot(dot1, 0.0, -1.0, opacity1);',
                    '    place_dot(dot2, 0.86, 0.50, opacity2);',
                    '    place_dot(dot3, -0.86, 0.50, opacity3);',
                    '  } else {',
                    '    dot1.SetOpacity(0.0);',
                    '    dot2.SetOpacity(0.0);',
                    '    dot3.SetOpacity(0.0);',
                    '    elapsed = now - global.start_time;',
                    '    opacity = elapsed / 0.65;',
                    '    if (global.quit_time > 0) opacity = 1.0 - ((now - global.quit_time) / 0.35);',
                    '    if (opacity < 0.0) opacity = 0.0;',
                    '    if (opacity > 1.0) opacity = 1.0;',
                    '    sprite.SetOpacity(opacity);',
                    '    phase = elapsed * 2.8;',
                    '    while (phase >= 3.0) phase = phase - 3.0;',
                    '    opacity1 = 1.0;',
                    '    opacity2 = 0.62;',
                    '    opacity3 = 0.28;',
                    '    if (phase >= 1.0) {',
                    '      if (phase < 2.0) {',
                    '        opacity1 = 0.28;',
                    '        opacity2 = 1.0;',
                    '        opacity3 = 0.62;',
                    '      }',
                    '    }',
                    '    if (phase >= 2.0) {',
                    '      opacity1 = 0.62;',
                    '      opacity2 = 0.28;',
                    '      opacity3 = 1.0;',
                    '    }',
                    '    place_boot_dot(dot1, -1.0, opacity1 * opacity);',
                    '    place_boot_dot(dot2, 0.0, opacity2 * opacity);',
                    '    place_boot_dot(dot3, 1.0, opacity3 * opacity);',
                    '  }',
                    '}',
                    '',
                    'fun quit_callback() {',
                    '  global.quit_time = Plymouth.GetTime();',
                    '}',
                    '',
                    'Plymouth.SetRefreshFunction(refresh_callback);',
                    'Plymouth.SetQuitFunction(quit_callback);',
                    "",
                ]
            ),
            0o644,
        )
        self.run(["plymouth-set-default-theme", "-R", "beenut"], check=False, quiet=True, allow_missing=True)
        if self.facts["has_systemd"]:
            for unit in [
                "plymouth-start.service",
                "plymouth-quit.service",
                "plymouth-quit-wait.service",
                "plymouth-reboot.service",
                "plymouth-poweroff.service",
                "plymouth-halt.service",
            ]:
                self.run(["systemctl", "enable", unit], check=False, quiet=True, allow_missing=True)
        self.run(["update-initramfs", "-u"], check=False, quiet=True, allow_missing=True)

    def configure_raspberry_pi_boot(self) -> None:
        config_path = Path("/boot/firmware/config.txt")
        cmdline_path = Path("/boot/firmware/cmdline.txt")
        if not config_path.parent.exists():
            if self.dry_run:
                self.step("dry-run: Raspberry Pi boot firmware directory not present on this host")
            else:
                self.step("Raspberry Pi boot firmware directory not found; Pi boot config skipped.")
                return
        config_content = "\n".join(
            [
                "# BeeNut appliance boot configuration",
                "arm_64bit=1",
                "camera_auto_detect=1",
                "dtoverlay=vc4-kms-v3d",
                "max_framebuffers=2",
                "disable_overscan=1",
                "dtparam=spi=on",
                "dtparam=i2c_arm=on",
                "",
            ]
        )
        cmdline_content = (
            "console=serial0,115200 console=tty3 root=/dev/mmcblk0p2 rootfstype=ext4 "
            "fsck.repair=yes rootwait quiet splash loglevel=0 systemd.show_status=0 "
            "rd.systemd.show_status=0 udev.log_level=3 rd.udev.log_level=3 "
            "vt.global_cursor_default=0 plymouth.enable=1\n"
        )
        if self.dry_run:
            self.step("dry-run: backup and write Raspberry Pi /boot/firmware boot config")
            return
        self.backup_file(config_path)
        self.backup_file(cmdline_path)
        write_text(config_path, config_content, 0o644)
        if cmdline_path.exists():
            write_text(cmdline_path, cmdline_content, 0o644)

    def apply_systemd_state(self, profile: Profile) -> None:
        if not self.facts["has_systemd"]:
            self.step("systemd is not running; service enable/start deferred.")
            return
        self.run(["systemctl", "daemon-reload"], check=False, quiet=True)
        self.run(["systemctl", "enable", "beenut-first-boot.service"], check=False, quiet=True)
        if profile.service_enabled:
            self.run(["systemctl", "enable", "beenut-service.service"], check=False, quiet=True)
            self.run(["systemctl", "restart", "beenut-service.service"], check=False, quiet=True)
        else:
            self.run(["systemctl", "stop", "beenut-service.service"], check=False, quiet=True)
            self.run(["systemctl", "disable", "beenut-service.service"], check=False, quiet=True)
        if profile.kiosk_enabled:
            self.run(["systemctl", "enable", "beenut-kiosk.service"], check=False, quiet=True)
            can_start_kiosk = profile.kiosk_mode == "flutter-pi" or self.facts["has_display"]
            if can_start_kiosk:
                self.run(["systemctl", "restart", "beenut-kiosk.service"], check=False, quiet=True)
            else:
                self.step("Kiosk service enabled but not started because no display was detected.")
        else:
            self.run(["systemctl", "disable", "beenut-kiosk.service"], check=False, quiet=True)
            self.run(["systemctl", "stop", "beenut-kiosk.service"], check=False, quiet=True)


def adapter_for(facts: dict[str, str | bool], dry_run: bool, apply_appliance_hardening: bool) -> BaseAdapter:
    if facts["system"] == "linux":
        return LinuxAdapter(facts, dry_run=dry_run, apply_appliance_hardening=apply_appliance_hardening)
    return UnsupportedAdapter(facts, dry_run=dry_run, apply_appliance_hardening=apply_appliance_hardening)


def print_detection(facts: dict[str, str | bool]) -> None:
    for key in sorted(facts):
        print(f"{key}: {facts[key]}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Configure BeeNut install profiles.")
    parser.add_argument("--profile", choices=sorted(PROFILES), help="Install profile to apply.")
    parser.add_argument("--detect", action="store_true", help="Print detected platform facts and exit.")
    parser.add_argument("--dry-run", action="store_true", help="Show intended changes without applying them.")
    parser.add_argument("--non-interactive", action="store_true", help="Do not prompt; use --profile or package defaults.")
    parser.add_argument("--no-appliance-hardening", action="store_true", help="Install services without changing boot, desktop login, GRUB, or splash settings.")
    parser.add_argument("--recover-desktop", action="store_true", help="Disable BeeNut kiosk services and restore graphical desktop boot.")
    args = parser.parse_args(argv)

    facts = detect()
    if args.detect:
        print_detection(facts)
        return 0
    if args.recover_desktop:
        adapter = adapter_for(
            facts,
            dry_run=args.dry_run,
            apply_appliance_hardening=not args.no_appliance_hardening,
        )
        if isinstance(adapter, LinuxAdapter):
            adapter.recover_desktop()
        else:
            raise SystemExit("--recover-desktop is currently implemented for Linux only.")
        return 0

    if args.profile:
        profile_key = args.profile
    elif args.non_interactive or not sys.stdin.isatty():
        profile_key = package_profile_default() or recommended_profile(facts)
    else:
        profile_key = choose_profile(facts)

    profile = PROFILES[profile_key]
    adapter_for(
        facts,
        dry_run=args.dry_run,
        apply_appliance_hardening=not args.no_appliance_hardening,
    ).apply(profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
