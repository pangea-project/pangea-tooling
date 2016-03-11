keyfile="/tmp/tmp.key"
rm -rf $keyfile
wget -O $keyfile "http://archive.neon.kde.org/public.key"
gpg --no-default-keyring --primary-keyring config/archives/ubuntu-defaults.key --import $keyfile
echo "deb http://archive.neon.kde.org/unstable $SUITE main" >> config/archives/neon.list
echo "deb-src http://archive.neon.kde.org/unstable $SUITE main" >> config/archives/neon.list
