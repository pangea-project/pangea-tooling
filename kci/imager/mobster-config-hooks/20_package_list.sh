cat << EOF >> config/package-lists/ubuntu-defaults.list.chroot_install
vim
konsole
kwin-wayland
kwin-wayland-backend-drm
plasma-phone-components
qtwayland5
xwayland
simplelogin
qtdeclarative5-private-dev
qml-module-org-kde-*
plasma-phone-dev-setup
qtdeclarative5-ofono0.2
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
plasma-volume-control
kinfocenter
muon
discover
koko
okular-mobile
vlc
gnome-chess
firefox
EOF

cat << EOF > config/package-lists/livecd-rootfs.list.chroot_live
lupin-casper
linux-signed-generic
!chroot chroot apt-cache dumpavail | grep-dctrl -nsPackage \\( -XFArchitecture amd64 -o -XFArchitecture all \\) -a -wFTask kubuntu-live | sed '/fcitx/d'
EOF
