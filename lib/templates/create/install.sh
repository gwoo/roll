#!/bin/bash
set -e

# Load base utility functions like szoo.mute() and szoo.install()
source szoo.sh

# Load configuration
source config.sh

# This line is necessary for automated provisioning for Debian/Ubuntu.
# Remove if you're not on Debian/Ubuntu.
export DEBIAN_FRONTEND=noninteractive

# Add Dotdeb repository. Recommended if you're using Debian. See http://www.dotdeb.org/about/
# source scripts/dotdeb.sh


# Install packages
apt-get -y install git-core ntp curl

# Install sysstat, then configure if this is a new install.
if szoo.install "sysstat"; then
  sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
  /etc/init.d/sysstat restart
fi

# Set RAILS_ENV
environment=<%= @attributes.environment %>

if ! grep -Fq "RAILS_ENV" ~/.bash_profile; then
  echo 'Setting up RAILS_ENV...'
  echo "export RAILS_ENV=$environment" >> ~/.bash_profile
  source ~/.bash_profile
fi

# Install Ruby using RVM
source scripts/rvm.sh
ruby_version=<%= @attributes.ruby_version %>

if [[ "$(which ruby)" != /usr/local/rvm/rubies/ruby-$ruby_version* ]]; then
  echo "Installing ruby-$ruby_version"
  # Install dependencies using RVM autolibs - see https://blog.engineyard.com/2013/rvm-ruby-2-0
  rvm install --autolibs=3 $ruby_version
  rvm $ruby_version --default
  echo 'gem: --no-ri --no-rdoc' > ~/.gemrc

  # Install Bundler
  gem install bundler
fi
