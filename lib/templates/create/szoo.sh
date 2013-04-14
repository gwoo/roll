# This file is used to define functions under the szoo.* namespace.

# Set $szoo_pkg to "apt-get" or "yum", or abort.
#
if which apt-get >/dev/null 2>&1; then
  export szoo_pkg=apt-get
elif which yum >/dev/null 2>&1; then
  export szoo_pkg=yum
elif which brew >/dev/null 2>&1; then
  export szoo_pkg=brew
fi

if [ "$szoo_pkg" = '' ]; then
  echo 'szoo only supports apt-get, yum and brew!' >&2
  exit 1
fi

# Mute STDOUT and STDERR
#
function szoo.mute() {
  echo "Running \"$@\""
  `$@ >/dev/null 2>&1`
  return $?
}

# Installer
#
function szoo.installed() {
  if [ "$szoo_pkg" = 'apt-get' ]; then
    dpkg -s $@ >/dev/null 2>&1
  elif [ "$szoo_pkg" = 'yum' ]; then
    rpm -qa | grep $@ >/dev/null
  fi
  return $?
}

# When there's "set -e" in install.sh, szoo.install should be used with if statement,
# otherwise the script may exit unexpectedly when the package is already installed.
#
function szoo.install() {
  for name in $@
  do
    if szoo.installed "$name"; then
      echo "$name already installed"
      return 1
    else
      echo "No packages found matching $name. Installing..."
      szoo.mute "$szoo_pkg -y install $name"
      return 0
    fi
  done
}