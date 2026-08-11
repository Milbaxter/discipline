#!/bin/bash
# One-time setup for discipline. Run with: sudo ./install.sh
# 1. Installs the hosts helper root-owned at /usr/local/bin/discipline-hosts
# 2. Adds a sudoers rule so your user can run ONLY that script without a password
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "run me with sudo: sudo ./install.sh" >&2
  exit 1
fi

# Invoking user: from sudo, or the console user when run via osascript.
TARGET_USER="${SUDO_USER:-$(stat -f%Su /dev/console)}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "could not determine the invoking user" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p /usr/local/bin
cp "$DIR/scripts/discipline-hosts" /usr/local/bin/discipline-hosts
chown root:wheel /usr/local/bin/discipline-hosts
chmod 755 /usr/local/bin/discipline-hosts

cat > /etc/sudoers.d/discipline <<EOF
$TARGET_USER ALL=(root) NOPASSWD: /usr/local/bin/discipline-hosts
EOF
chmod 440 /etc/sudoers.d/discipline

echo "installed. test with: sudo -n /usr/local/bin/discipline-hosts status"
