#!/usr/bin/env sh
set -eu

cat > /etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_RECORDFAIL_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_DISTRIBUTOR="BeeNut"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 systemd.show_status=false rd.systemd.show_status=false splash vt.global_cursor_default=0 console=tty3"
GRUB_CMDLINE_LINUX=""
EOF

if command -v update-grub >/dev/null 2>&1; then
  update-grub || true
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme spinner || true
fi
