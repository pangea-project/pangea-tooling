apt-key export '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D' > config/archives/ubuntu-defaults.key
# make sure _apt can read this file. it may get copied into the chroot
chmod 644 config/archives/ubuntu-defaults.key || true

echo "deb http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list
