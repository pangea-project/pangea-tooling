# konsole needs installed first else xterm gets installed cos xorg deps on
# terminal | xterm and doesn't know terminal is installed later in the tree
cat << EOF > config/package-lists/ubuntu-defaults.list.chroot_install
konsole
vim
kwin-wayland
kwin-wayland-backend-drm
plasma-phone-components
qtwayland5
xwayland
simplelogin
qtdeclarative5-private-dev
plasma-phone-dev-setup
plasma-phone-settings
kpackagelauncherqml
kwin-style-breeze
plasma-nm
plasma-camera
plasma-maliit-framework
plasma-maliit-plugins
plasma-sdk
plasma-settings
kdeconnect-plasma
kinfocenter
vlc
gnome-chess
EOF

cat << EOF > config/package-lists/livecd-rootfs.list.chroot_live
lupin-casper
linux-signed-generic
!chroot chroot apt-cache dumpavail | grep-dctrl -nsPackage \\\\( -XFArchitecture amd64 -o -XFArchitecture all \\\\) -a -wFTask kubuntu-live | sed '/fcitx/d'
EOF
