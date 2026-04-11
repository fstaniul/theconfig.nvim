#!/usr/bin/bash
set -euo pipefail

if [ ! -d /opt/nvim ]; then
	echo "nvim not installed manually at /opt/nvim, aborting." >&2
	exit 127
fi

ARCH=$(uname -m)
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
	x86_64|arm64) ;;
	*)
		echo "Unsupported architecture: $ARCH" >&2
		exit 1
		;;
esac

case "$PLATFORM" in
	linux) ;;
	darwin) PLATFORM="macos";;
	*)
		echo "Unsupported platform: $PLATFORM" >&2
		exit 1
		;;
esac

DIR="nvim-$PLATFORM-$ARCH"
TARBALL="$DIR.tar.gz"

gh release download --repo neovim/neovim --dir . --pattern "$TARBALL"
if [ ! -f "./$TARBALL" ]; then
	echo "Failed to download release tarball, aborting." >&2
	exit 1
fi

sudo tar -xzf "./$TARBALL"
rm "./$TARBALL"
if [ ! -d "./$DIR" ]; then
	echo "Failed to extract the tarball, aborting." >&2
	exit 1
fi

sudo mv /opt/nvim /opt/nvim-old

trap 'if [ -d /opt/nvim-old ]; then sudo rm -rf /opt/nvim; sudo mv /opt/nvim-old /opt/nvim; echo "Failed to install nvim, reverted to previous instalation." >&2; fi' ERR

sudo mv "./$DIR" /opt/nvim

command -v nvim >/dev/null 2>&1 || false

nvim --version

# vim ft=bash
