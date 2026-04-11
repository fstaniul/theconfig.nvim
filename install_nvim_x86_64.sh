#!/usr/bin/bash
set -euo pipefail

gh release download --repo neovim/neovim --dir . --pattern 'nvim-linux-x86_64.tar.gz'
sudo tar -xzf ./nvim-linux-x86_64.tar.gz
rm ./nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim /opt/nvim-old
sudo mv ./nvim-linux-x86_64 /opt/nvim
if command -v nvim >/dev/null 2>&1; then
	sudo rm -rf /opt/nvim-old
fi
nvim --version

# vim ft=bash
