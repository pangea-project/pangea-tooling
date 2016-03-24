Format: 3.0 (quilt)
Source: gpgmepp
Binary: libkf5gpgmepp5, libkf5gpgmepp-pthread5, libkf5gpgmepp-dev, libkf5qgpgme5, gpgmepp-dbg
Architecture: any
Version: 15.08.2+git20151212.1109+15.04-0
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Homepage: https://projects.kde.org/projects/kde/pim/gpgmepp
Standards-Version: 3.9.6
Vcs-Browser: http://anonscm.debian.org/cgit/pkg-kde/applications/gpgmepp.git
Vcs-Git: git://anonscm.debian.org/pkg-kde/applications/gpgmepp.git
Testsuite: autopkgtest
Build-Depends: cmake (>= 2.8.12~), debhelper (>= 9), extra-cmake-modules (>= 5.12.0~), libboost-dev, libgpgme11-dev, pkg-kde-tools (>> 0.15.15), qtbase5-dev
Package-List:
 gpgmepp-dbg deb debug extra arch=any
 libkf5gpgmepp-dev deb libdevel optional arch=any
 libkf5gpgmepp-pthread5 deb libs optional arch=any
 libkf5gpgmepp5 deb libs optional arch=any
 libkf5qgpgme5 deb libs optional arch=any
Checksums-Sha1:
 da39a3ee5e6b4b0d3255bfef95601890afd80709 0 file
Checksums-Sha256:
 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 0 file
Files:
 d41d8cd98f00b204e9800998ecf8427e 0 file
Original-Maintainer: Debian/Kubuntu Qt/KDE Maintainers <debian-qt-kde@lists.debian.org>
