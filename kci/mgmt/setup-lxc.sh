#!/bin/sh

set -e

sudo apt-get update
sudo apt-get install -y git sudo wget apt-cacher

echo 'Acquire::http { Proxy "http://localhost:3142"; };' > /etc/apt/apt.conf.d/00apt-cacher

wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install jenkins

# Prevent hard restarts on upgrades
chmod -x /etc/init.d/jenkins

apt install -y lxc systemd-services uidmap
usermod --add-subuids 100000-165536 jenkins
usermod --add-subgids 100000-165536 jenkins
chmod +x $(getent passwd "jenkins" | cut -d: -f6)

echo 'jenkins veth lxcbr0 128' >> /etc/lxc/lxc-usernet

## in jenkins

mkdir -p $HOME/.config/lxc/
cat << EOF > $HOME/.config/lxc/default.conf
lxc.network.type = veth
lxc.network.link = lxcbr0
lxc.network.flags = up
lxc.network.hwaddr = 00:16:3e:xx:xx:xx
lxc.id_map = u 0 $(id -u jenkins) 1
lxc.id_map = g 0 $(id -g jenkins) 1
lxc.id_map = u 1 100000 65536
lxc.id_map = g 1 100000 65536
EOF

