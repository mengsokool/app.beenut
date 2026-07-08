#!/usr/bin/env sh
set -eu

if command -v grub-install >/dev/null 2>&1; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --boot-directory=/boot --removable || true
fi
