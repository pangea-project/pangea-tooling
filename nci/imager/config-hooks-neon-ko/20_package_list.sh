# konsole needs installed first else xterm gets installed cos xorg deps on
# terminal | xterm and doesn't know terminal is installed later in the tree
cat << EOF > config/package-lists/ubuntu-defaults.list.chroot_install
konsole
neon-desktop-ko
EOF
