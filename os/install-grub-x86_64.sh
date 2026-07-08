#!/usr/bin/env sh
set -eu

if command -v grub-install >/dev/null 2>&1; then
  grub-install --target=i386-pc --boot-directory=/boot /dev/loop0 || true
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --removable || true
fi
