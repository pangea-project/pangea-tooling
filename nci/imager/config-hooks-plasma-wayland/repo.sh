gpg --no-default-keyring \
  --primary-keyring config/archives/ubuntu-defaults.key \
  --keyserver keyserver.ubuntu.com \
  --recv-keys '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D'
echo "deb http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list
