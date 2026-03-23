#!/usr/bin/env bash

fatal() {
  echo "fatal: $1" >&2
  exit 1;
}

warn() {
  echo "warn: $1" >&2
  return 1
}

debug() {
  echo "debug: $@"
}

FORCE=false
DEBUG=false
DRY_RUN=false

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    printf "\e[1;33m[DRY-RUN]:\e[0m "
    echo "$@"
    return 0
  else
    debug "running: $@"
    "$@" || warn "failed to run: $@"
    return $?
  fi
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      shift
      ;;
    -d|--debug)
      DEBUG=true
      DRY_RUN=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

brew_install() {
  if [[ -z "$1" ]]; then
    fatal "brew_install is missing required parameter"
  fi

  local pkg=$1

  if ! brew list "$pkg"  &> /dev/null; then
    debug "installing $pkg..."
    run_cmd brew install "$pkg" || warn "failed to install $pkg"
  else
    debug "upgrading $pkg..."
    run_cmd brew upgrade "$pkg"
  fi
}

install_colorscripts() {
  if ! command -v colorscripts &>/dev/null; then
    echo 'installing colorscripts...'
    run_cmd git clone https://gitlab.com/dwt1/shell-color-scripts.git ~/.local/colorscripts || warn 'failed to clone colorscript, see: https://gitlab.com/dwt1/shell-color-scripts'
    if [[ $? -ne 0 ]]; then
      return 1
    fi

    run_cmd cd ~/.local/colorscripts
    run_cmd sudo make install && echo "installed color scripts" || warn 'failed to install colorscripts'
    run_cmd rm -rf ~/.local/colorscripts || warn 'failed to remove ~/.local/colorscripts'
    run_cmd cd -
  fi
}

echo 'preparing neovim dependencies...'
for dep in fd ripgrep tree-sitter-cli unzip; do
  brew_install "$dep" || fatal "failed to install $dep"
done

brew_install neovim || fatal 'failed to install neovim'

FONT="SauceCodePro Nerd Font Mono"
if ! fc-list ":family=$FONT" | grep -iq "$FONT"; then
  echo 'installing $FONT...'
  brew install --cask font-sauce-code-pro-nerd-font || warn 'failed to install Sauce Code Pro Nerd Font, install with: \n\t brew install --cask font-sauce-code-pro-nerd-font'
fi

if [[ "$FORCE" == true ]]; then
  echo 'cleaning previous config...'
  run_cmd rm -rf ~/.local/share/nvim
  run_cmd rm -rf ~/.config/nvim
fi

DST="~/.config/nvim"
debug "DST=$DST FORCE=$FORCE"
if [[ "$FORCE" == true || ! -d "$DST" ]]; then
  echo 'cloning config...'
  run_cmd git clone https://github.com/fstaniul/theconfig.nvim.git "$DST" || fatal 'failed to clone config'
fi

# install additional dependencies
brew_install gh
install_colorscripts

echo "done."

# vim: ts=2 sts=2 sw=2 et
