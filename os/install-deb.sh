#!/bin/sh
# Shell script to install the BeeNut Debian package inside the chroot rootfs.
set -e

PACKAGE_DIR="${BEENUT_PACKAGE_DIR:-/opt/beenut-packages}"
DEB_FILE=$(find "$PACKAGE_DIR" -type f -name 'beenut_*.deb' 2>/dev/null | sort | head -n 1)
if [ -f "$DEB_FILE" ]; then
  echo "Installing $DEB_FILE inside rootfs..."
  apt-get install -y "$DEB_FILE"
else
  echo "Error: BeeNut Debian package not found under $PACKAGE_DIR" >&2
  find "$PACKAGE_DIR" -maxdepth 3 -type f -print 2>/dev/null || true
  exit 1
fi
rm -rf "$PACKAGE_DIR"
