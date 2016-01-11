cat << EOF > config/package-lists/livecd-rootfs.list.chroot_live
lupin-casper
linux-signed-generic
!chroot chroot apt-cache dumpavail | grep-dctrl -nsPackage \\\\( -XFArchitecture amd64 -o -XFArchitecture all \\\\) -a -wFTask kubuntu-live | sed '/fcitx/d' | sed '/kde-l10n/d' | sed '/k3b-i18n/d'
EOF
