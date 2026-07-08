#!/usr/bin/env sh
set -eu

mkdir -p /boot/firmware

cat > /boot/firmware/config.txt <<'EOF'
# BeeNut OS Boot Configuration
arm_64bit=1
camera_auto_detect=1
dtoverlay=vc4-kms-v3d
max_framebuffers=2
disable_overscan=1
# Enable SPI and I2C for GPIO hardware interfacing
dtparam=spi=on
dtparam=i2c_arm=on
EOF

cat > /boot/firmware/cmdline.txt <<'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles
EOF
