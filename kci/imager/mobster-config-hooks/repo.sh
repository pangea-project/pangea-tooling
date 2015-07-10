keyfile="/tmp/tmp.key"
rm -rf $keyfile
wget -O $keyfile "http://mobile.kci.pangea.pub/Pangea%20CI.gpg.key"
gpg --no-default-keyring --primary-keyring config/archives/ubuntu-defaults.key --import $keyfile
echo "deb [arch=amd64] http://mobile.kci.pangea.pub $SUITE main" >> config/archives/ubuntu-defaults.list
