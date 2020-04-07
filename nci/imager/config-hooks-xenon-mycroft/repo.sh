# Use gpg1, mostly because we are lazy and don't know how to best port this to v2
apt install -y dirmngr gnupg1
ARGS="--batch --verbose"
GPG="gpg1"

$GPG --list-keys

$GPG \
  $ARGS \
  --no-default-keyring \
  --primary-keyring config/archives/ubuntu-defaults.key \
  --keyserver pool.sks-keyservers.net \
  --recv-keys '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D'
echo "deb http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.neon.kde.org/${NEONARCHIVE} $SUITE main" >> config/archives/neon.list

$GPG \
  $ARGS \
  --no-default-keyring \
  --primary-keyring config/archives/ubuntu-defaults.key \
  --keyserver keyserver.ubuntu.com \
  --recv-keys 'CB87 A99C D05E 5E0C 7017  4A68 E8AF 1B0B 45D8 3EBD'

echo "deb http://archive.xenon.pangea.pub/unstable $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.xenon.pangea.pub/unstable $SUITE main" >> config/archives/neon.list

# make sure _apt can read this file. it may get copied into the chroot
chmod 644 config/archives/ubuntu-defaults.key || true
