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
szoo.install "git-core ntp curl htop"

# Install sysstat, then configure if this is a new install.
if sunzi.install "sysstat"; then
  sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
  /etc/init.d/sysstat restart
fi

