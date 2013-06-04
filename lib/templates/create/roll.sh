# This file is used to define functions under the roll.* namespace.

# Set $roll_pkg to "apt-get" or "yum", or abort.
#
if which apt-get >/dev/null 2>&1; then
  export roll_pkg=apt-get
elif which yum >/dev/null 2>&1; then
  export roll_pkg=yum
elif which brew >/dev/null 2>&1; then
  export roll_pkg=brew
fi

if [ "$roll_pkg" = '' ]; then
  echo 'roll only supports apt-get, yum and brew!' >&2
  exit 1
fi

# Mute STDOUT and STDERR
#
function roll.mute() {
  echo "Running \"$@\""
  `$@ >/dev/null 2>&1`
  return $?
}

# Installer
#
function roll.installed() {
  if [ "$roll_pkg" = 'apt-get' ]; then
    dpkg -s $@ >/dev/null 2>&1
  elif [ "$roll_pkg" = 'yum' ]; then
    rpm -qa | grep $@ >/dev/null
  fi
  return $?
}

# When there's "set -e" in install.sh, roll.install should be used with if statement,
# otherwise the script may exit unexpectedly when the package is already installed.
#
function roll.install() {
  for name in $@
  do
    if roll.installed "$name"; then
      echo "$name installed"
      return 1
    else
      echo "No packages found matching $name. Installing..."
      roll.mute "$roll_pkg -y install $name"
      return 0
    fi
  done
}

# Download some files and extract them
function roll.get() {
  roll.download ${@}
  set -- "${@:2}"
  roll.extract ${@}
}

# Download a file
function roll.download() {
  mirror=$1
  name=$2
  type=$3
  file="${name}.${type}"
  if [ ! -f "${file}" ]; then
    echo "Downloading ${file}"
    curl -s -C - -O "${mirror}/${file}"

    if [ ! -f "${file}" ]; then
      echo "Could not download ${file}"
      exit 1
    fi
  fi
}

# Extract a file
function roll.extract() {
  name=$1
  type=$2
  file="${name}.${type}"
  if [ ! -d "${name}" ]; then
    echo "Extracting ${file}"
    tar -xf "${file}"

    if [ ! -d "${name}" ]; then
      echo "Could not extract ${name}"
      exit 1
    fi
  fi
}