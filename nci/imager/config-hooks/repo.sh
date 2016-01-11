keyfile="/tmp/tmp.key"
rm -rf $keyfile
wget -O $keyfile "http://archive.neon.kde.org.uk/public.key"
gpg --no-default-keyring --primary-keyring config/archives/ubuntu-defaults.key --import $keyfile
echo "deb [arch=amd64] http://archive.neon.kde.org.uk/unstable $SUITE main" >> config/archives/ubuntu-defaults.list
