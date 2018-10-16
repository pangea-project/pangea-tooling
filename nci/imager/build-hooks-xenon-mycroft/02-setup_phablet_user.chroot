#!/bin/sh -x

USER=phablet
GECOS=phablet
UGID=32011

DEFGROUPS="tty,sudo,adm,dialout,cdrom,plugdev,audio,dip,video"

echo "I: creating default user $USER"
adduser --gecos $GECOS --disabled-login $USER --uid $UGID

echo "I: set user $USER password to 1234"
echo "phablet:1234" | /usr/sbin/chpasswd

mkdir -p /home/$USER/Music
mkdir -p /home/$USER/Pictures
mkdir -p /home/$USER/Videos
mkdir -p /home/$USER/Downloads
mkdir -p /home/$USER/Documents
chown -R $UGID:$UGID /home/$USER

usermod -a -G ${DEFGROUPS} ${USER}

# if mycroft is installed, chown it to phablet user
chown -Rv phablet /opt/mycroft || true
chown -Rv phablet /var/log/mycroft || true

if [ -e /home/phablet ] && [ ! -e /home/phablet/mycroft-core ]; then
    ln -s /opt/mycroft /home/phablet/mycroft-core
fi
