# shellcheck shell=sh disable=SC1091
### PATH -------------------------------------------------------------------
if [ -d "$HOME/bin" ]; then
  case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) PATH="$HOME/bin:$PATH" ;;
  esac
fi

if [ -d "$HOME/.npm-global/bin" ]; then
  case ":$PATH:" in
  *":$HOME/.npm-global/bin:"*) ;;
  *) PATH="$HOME/.npm-global/bin:$PATH" ;;
  esac
fi

if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

### INTERACTIVE BASH -------------------------------------------------------
if [ "$BASH_VERSION" != "" ]; then
  if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  fi
fi
