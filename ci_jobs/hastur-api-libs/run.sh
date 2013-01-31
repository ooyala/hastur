#!/bin/bash
set -ex

eval "$(rbenv init -)"

# The current working directory is exactly WORKSPACE.
# This is where each repo the test requires is checked out to.
: ${OOYALA_REPO_ROOT:="$WORKSPACE"}

# Setup a 1.9.2-p290 test environment
rbenv shell 1.9.2-p290

gem install --no-rdoc --no-ri bundler

# Move to the project repo
cd $WORKSPACE/hastur

# install the necessary gems and execute tests
bundle install

# just in case we installed some executables...
rbenv rehash

COVERAGE=true bundle exec rake --trace test:units
