keyfile="/tmp/tmp.key"
rm -rf $keyfile
wget -O $keyfile "http://mobile.neon.pangea.pub/Pangea%20CI.gpg.key"
gpg --no-default-keyring --primary-keyring config/archives/ubuntu-defaults.key --import $keyfile
echo "deb http://mobile.neon.pangea.pub $SUITE main" >> config/archives/mci.list
echo "deb-src http://mobile.neon.pangea.pub $SUITE main" >> config/archives/mci.list
