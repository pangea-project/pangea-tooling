FROM debian:<%= series %>

ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.UTF-8

# Containerized Jenkins has a UID/GID of 1000
# So lets just use that everywhere.

RUN addgroup \
  --system \
  --gid 1000 \
  jenkins

RUN adduser \
  --system \
  --home <%= jenkins_home %> \
  --uid 1000 \
  --ingroup jenkins \
  --disabled-password \
  jenkins

# FIXME: todo
# RUN echo 'Acquire::http { Proxy "http://10.0.3.1:3142"; };' > /etc/apt/apt.conf.d/00cache
RUN echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/00aptitude
RUN echo 'APT::Color "1";' > /etc/apt/apt.conf.d/99color

RUN apt update && apt dist-upgrade -y
RUN apt install -y xz-utils dpkg-dev dput debhelper pkg-kde-tools \
                   devscripts ubuntu-dev-tools git locales \
                   dh-systemd zlib1g-dev python-paramiko \
                   curl gawk libreadline6-dev libssl-dev libyaml-dev \
                   libsqlite3-dev sqlite3 autoconf libgdbm-dev \
                   libncurses5-dev automake libtool bison pkg-config libffi-dev

# RUN echo 'LANG=en_US.UTF-8' >> /etc/profile
# RUN echo 'LANG=en_US.UTF-8' >> /etc/environment
# RUN /usr/sbin/update-locale LANG=en_US.UTF-8
USER jenkins
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
RUN curl -sSL https://get.rvm.io | bash -s stable --ruby --auto-dotfiles
RUN /bin/bash -lc "gem install bundler"
RUN /bin/bash -lc "git config --global user.email "rohan@garg.io" && \
    git config --global user.name "Debian CI" && \
    mkdir -p ~/.ssh && \
    ssh-keyscan github.com &> ~/.ssh/known_hosts && \
    ssh-keyscan git.debian.org &> ~/.ssh/known_hosts"
