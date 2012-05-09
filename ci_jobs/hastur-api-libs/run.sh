#!/bin/bash

: ${REPO_ROOT:="$WORKSPACE"}
source $HOME/.rvm/scripts/rvm

cd $REPO_ROOT/hastur
rvm --create use 1.9.3@hastur
gem install --no-rdoc --no-ri bundler
bundle install
COVERAGE=true bundle exec rake --trace test:units
