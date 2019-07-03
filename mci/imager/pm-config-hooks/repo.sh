keyfile="/tmp/tmp.key"
rm -rf $keyfile
wget -O $keyfile "http://repo.plasma-mobile.org/Pangea%20CI.gpg.key"
gpg --no-default-keyring --primary-keyring config/archives/ubuntu-defaults.key --import $keyfile
echo "deb http://repo.plasma-mobile.org $SUITE main" >> config/archives/mci.list
echo "deb-src http://repo.plasma-mobile.org $SUITE main" >> config/archives/mci.list
