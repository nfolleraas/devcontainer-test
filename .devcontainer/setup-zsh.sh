#!/usr/bin/env bash
# Configures Oh My Zsh. Safe to rerun on every container creation.
set -euo pipefail

THEME="jnrowe"
PLUGINS="git zsh-autosuggestions zsh-syntax-highlighting"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

clone() {
  [ -d "$2" ] || git clone --depth=1 "$1" "$2"
}

clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$THEME\"/" "$HOME/.zshrc"
sed -i "s/^plugins=.*/plugins=($PLUGINS)/" "$HOME/.zshrc"
