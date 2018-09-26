. /etc/os-release # to get access to version_codename; NB: of host container!

GPG="gpg"
ARGS=""
if [ "$VERSION_CODENAME" = "bionic" ]; then
  apt install -y dirmngr gnupg1
  ARGS="--batch --verbose"
  GPG="gpg1"
fi

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
  --keyserver pool.sks-keyservers.net \
  --recv-keys 'E47F 5011 FA60 FC1D EBB1  9989 3305 6FA1 4AD3 A421'

echo "deb http://archive.xenon.pangea.pub/unstable $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.xenon.pangea.pub/unstable $SUITE main" >> config/archives/neon.list

# make sure _apt can read this file. it may get copied into the chroot
chmod 644 config/archives/ubuntu-defaults.key || true
