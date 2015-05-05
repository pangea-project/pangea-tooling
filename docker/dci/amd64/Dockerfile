FROM debian:sid

MAINTAINER Rohan Garg <rohan@garg.io>

RUN apt-get update && apt-get -y install git-core ruby cdbs pkg-kde-tools devscripts
RUN mkdir -p /root/.ssh/
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN ssh-keyscan git.debian.org >> /root/.ssh/known_hosts
RUN git clone https://github.com/blue-systems/pangea-tooling.git /opt/tooling
RUN git clone https://anonscm.debian.org/git/pkg-kde/ci-tooling.git /opt/tooling/ci-tooling
RUN useradd -m buildd -u 5000
