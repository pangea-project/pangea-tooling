# konsole needs installed first else xterm gets installed cos xorg deps on
# terminal | xterm and doesn't know terminal is installed later in the tree.
# Also explicitly install the efi image packages explicitly so live-build
# can find them for extraction into the ISO.
cat << EOF > config/package-lists/ubuntu-defaults.list.chroot_install
shim-signed
grub-efi-arm64
grub-efi-arm64-bin
konsole
neon-desktop
EOF
