#!/bin/bash

# unset rvm variables because lxc-attach doesn't drop the host env
unset GEM_PATH
unset GEM_HOME
unset IRBRC
unset MY_RUBY_HOME
unset RUBY_VERSION

export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH

read -r -d '' PACKAGES << EOF
  xz-utils dpkg-dev ruby dput debhelper pkg-kde-tools devscripts
  python-launchpadlib ubuntu-dev-tools git dh-systemd ruby-dev
  zlib1g-dev python-paramiko
EOF

function cleanup {
  lxc-stop -n $NAME || true
  lxc-wait -n $NAME --state=STOPPED --timeout=30 || true
}
trap cleanup EXIT

if ! lxc-ls | grep $NAME; then
  lxc-create -t $TEMPLATE -n $NAME -- -d $DIST -r $RELEASE -a $ARCH
fi

# Restore previous backups if any
if [ -f $HOME/.local/share/lxc/$NAME/config.bak ]; then
  mv $HOME/.local/share/lxc/$NAME/config.bak $HOME/.local/share/lxc/$NAME/config
fi

if [ -d $HOME/tooling-pending ]; then
  cp $HOME/.local/share/lxc/$NAME/config $HOME/.local/share/lxc/$NAME/config.bak
  echo "lxc.mount.entry = $HOME/tooling-pending var/lib/jenkins/tooling-pending none bind,create=dir" >> $HOME/.local/share/lxc/$NAME/config
fi

lxc-ls -f

lxc-wait -n $NAME --state=STOPPED --timeout=30
lxc-start -n $NAME --daemon
lxc-wait -n $NAME --state=RUNNING --timeout=30

for i in $(seq 1 $TIMEOUT); do
  if [ -n "$(lxc-info --no-humanize --ips -n $NAME)" ]; then
    HAS_IP=true
    break
  fi
  sleep 1
done
if [ ! $HAS_IP ]; then
  echo "For some reason the container did not get an IP address. Aborting..."
  exit 1
fi
lxc-ls -f

echo 'Acquire::http { Proxy "http://10.0.3.1:3142"; };' | lxc-attach -n $NAME tee /etc/apt/apt.conf.d/apt-cacher
echo 'Acquire::Languages "none";' | lxc-attach -n $NAME tee /etc/apt/apt.conf.d/00aptitude
echo 'APT::Color "1";' | lxc-attach -n $NAME tee /etc/apt/apt.conf.d/99color
lxc-attach -n $NAME -- apt-get update
lxc-attach -n $NAME -- apt-get dist-upgrade -y
lxc-attach -n $NAME -- apt-get install $PACKAGES -y

lxc-attach -n $NAME -- gem install bundler
lxc-attach -n $NAME -- bash -c "cd $HOME/tooling-pending && bundle install --no-cache --local --frozen --system --without development test"
lxc-attach -n $NAME -- rm -rf $HOME/ci-tooling $HOME/.gem $HOME/.rvm
lxc-attach -n $NAME -- cp -r $HOME/tooling-pending/ci-tooling $HOME/ci-tooling

lxc-stop -n $NAME
lxc-wait -n $NAME --state=STOPPED --timeout=30

mv $HOME/.local/share/lxc/$NAME/config.bak $HOME/.local/share/lxc/$NAME/config
