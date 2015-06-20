#!/bin/sh

set -ex

SCRIPTDIR=$(readlink -f $(dirname -- "$0"))

export GEM_HOME=$(ruby -rubygems -e 'puts Gem.user_dir')
export GEM_PATH=$GEM_HOME:$HOME/.gems/bundler
export PATH=$GEM_HOME/bin:$PATH

cd $SCRIPTDIR
gem install bundler
gem update bundler
bundle install --jobs=`nproc` --no-cache --local --frozen --system --without development test

rm -rf $SCRIPTDIR/../tooling
cp -rf $SCRIPTDIR $SCRIPTDIR/../tooling
