FROM ubuntu:15.04

ENV DEBIAN_FRONTEND noninteractive

# Create a mock group and user. Docker 1.5 does not support subuid maps, so
# everything written as root in the container is actually written by root.
# To prevent rooted stuff ending up in our home we will chown -R with the mock
# user and group that map to the actual uid and gid on the host.
RUN addgroup \
  --system \
  --gid 120 \
  jenkins

RUN adduser \
  --system \
  --home /var/lib/jenkins \
  --no-create-home \
  --uid 100000 \
  --ingroup jenkins \
  --disabled-password \
  jenkins

# FIXME: todo
#RUN echo 'Acquire::http { Proxy "http://10.0.3.1:3142"; };' | lxc-attach -n $NAME tee /etc/apt/apt.conf.d/apt-cacher
RUN echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/00aptitude
RUN echo 'APT::Color "1";' > /etc/apt/apt.conf.d/99color

RUN apt update
RUN apt dist-upgrade -y
RUN apt install -y xz-utils dpkg-dev ruby dput debhelper pkg-kde-tools \
                   devscripts python-launchpadlib ubuntu-dev-tools git \
                   dh-systemd ruby-dev zlib1g-dev python-paramiko

VOLUME ["/var/lib/jenkins/tooling-pending"]

RUN gem install bundler
RUN bash -c "cd /var/lib/jenkins/tooling-pending && bundle install --no-cache --local --frozen --system --without development test"
RUN rm -rf /var/lib/jenkins/ci-tooling /var/lib/jenkins/.gem /var/lib/jenkins/.rvm
RUN cp -r /var/lib/jenkins/tooling-pending/ci-tooling /var/lib/jenkins/ci-tooling

USER me
