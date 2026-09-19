# shellcheck shell=sh disable=SC1091
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

if [ -d "$HOME/.npm-global/bin" ]; then
  case ":$PATH:" in
  *":$HOME/.npm-global/bin:"*) ;;
  *) PATH="$HOME/.npm-global/bin:$PATH" ;;
  esac
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ]; then
  case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) PATH="$HOME/bin:$PATH" ;;
  esac
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# if running bash
if [ "$BASH_VERSION" != "" ]; then
  # include .bashrc if it exists
  if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  fi
fi
