gpg --no-default-keyring \
  --primary-keyring config/archives/ubuntu-defaults.key \
  --keyserver keyserver.ubuntu.com \
  --recv-keys '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D'
echo "deb http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list

wget -O $keyfile "http://neon.plasma-mobile.org:8080/Pangea%20CI.gpg.key"
gpg --no-default-keyring --primary-keyring config/archives/ubuntu-defaults.key --import $keyfile
echo "deb http://neon.plasma-mobile.org:8080/ $SUITE main" >> config/archives/pm.list
echo "deb-src http://neon.plasma-mobile.org:8080/ $SUITE main" >> config/archives/pm.list
