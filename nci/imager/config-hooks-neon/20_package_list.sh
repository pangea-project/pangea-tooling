# konsole needs installed first else xterm gets installed cos xorg deps on
# terminal | xterm and doesn't know terminal is installed later in the tree.
# Also explicitly install the efi image packages explicitly so live-build
# can find them for extraction into the ISO.
# colord gets removed because it would get dragged in by cups but after
# discussion with Rohan Garg I've come to the conclusion that colord makes
# no sense by default. If the user wants to do color profile management, sure,
# but this is a very specific desire usually requiring very specific hardware
# to perform the calibration. Without a profile colord adds no value so
# we may as well not ship it by default.
cat << EOF > config/package-lists/ubuntu-defaults.list.chroot_install
shim-signed
grub-efi-amd64-signed
grub-efi-ia32-bin
konsole
neon-desktop
colord-
EOF
