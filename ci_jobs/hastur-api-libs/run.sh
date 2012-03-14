#!/bin/bash

: ${REPO_ROOT:="$WORKSPACE"}
source $HOME/.rvm/scripts/rvm

cd $REPO_ROOT/hastur/ruby
rvm --create use 1.9.3@hastur
gem install --no-rdoc --no-ri bundler
bundle install
COVERAGE=true rake --trace test:units
