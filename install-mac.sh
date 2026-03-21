#!/usr/bin/env bash

fatal() {
  echo "FATAL: $1";
  exit 1;
}

warn() {
  echo "WARNING: $1"
}

echo 'install neovim dependencies...'
brew install fd ripgrep tree-sitter-cli unzip || fatal 'failed to install dependencies'

echo 'install neovim...'
brew install neovim || fatal 'failed to install neovim'

echo 'install sauce code pro nerd font...'
brew install --cask font-sauce-code-pro-nerd-font || warn 'failed to install Sauce Code Pro Nerd Font, install with: \n\t brew install --cask font-sauce-code-pro-nerd-font'

echo 'clean previous config (destructive)'
rm -rf ~/.local/share/nvim
rm -rf ~/.config/nvim

echo 'clone nvim...'
git clone https://github.com/fstaniul/theconfig.nvim.git ~/.config/nvim

echo "done."

# vim: ts=2 sts=2 sw=2 et
