# shellcheck shell=bash disable=SC1091
### INTERACTIVE CHECK -------------------------------------------------------

case $- in
*i*) ;;
*) return ;;
esac

### LINE EDITOR -------------------------------------------------------------

if [ -f ~/.local/share/blesh/ble.sh ]; then
  # shellcheck source=/dev/null
  source -- ~/.local/share/blesh/ble.sh --attach=none
fi

### HISTORY -----------------------------------------------------------------

HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T  "
HISTSIZE=10000
HISTFILESIZE=20000

### SHELL OPTIONS -----------------------------------------------------------

shopt -s histappend
shopt -s cmdhist
shopt -s lithist
shopt -s checkwinsize
shopt -s cdspell
shopt -s dirspell
shopt -s autocd
shopt -s extglob

set -o noclobber

### READLINE ----------------------------------------------------------------

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous off'
bind 'set mark-symlinked-directories on'

### PATH --------------------------------------------------------------------

case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
fi

### PROMPT ------------------------------------------------------------------

if [ "${debian_chroot:-}" = "" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt

case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  ;;
esac

### VENV PROMPT FIX (Positron shell integration workaround) -----------------

case "$PROMPT_COMMAND" in
*__fix_venv_prompt*) ;;
*) PROMPT_COMMAND="__fix_venv_prompt; history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

export VIRTUAL_ENV_DISABLE_PROMPT=1

__base_ps1="$PS1"

__fix_venv_prompt() {
  if [ "$VIRTUAL_ENV" != "" ]; then
    PS1="(${VIRTUAL_ENV_PROMPT:-$(basename "$VIRTUAL_ENV")}) $__base_ps1"
  else
    PS1="$__base_ps1"
  fi
}

### COLORS ------------------------------------------------------------------

if [ -x /usr/bin/dircolors ]; then
  if [ -r ~/.dircolors ]; then
    eval "$(dircolors -b ~/.dircolors)"
  else
    eval "$(dircolors -b)"
  fi
  LS_COLORS+=":su=30;41:ow=30;42:st=30;44"
fi

### PAGER -------------------------------------------------------------------

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

export BAT_THEME=ansi

### ALIASES -----------------------------------------------------------------

alias firmup='fwupdmgr refresh && fwupdmgr update'

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias qp='rm -rf .quarto; quarto preview'
alias yolo='git add . && git commit -m "."'
alias fd=fdfind
alias bat=batcat
alias firefox='firefox --profile /home/julien/.mozilla/firefox/z24d9fn6.default-release'

st-tp2() {
  ssh ju-TP2 bash -s <<'EOF'
    url=http://127.0.0.1:8385
    cmd=/mnt/c/Windows/System32/cmd.exe
    interop=$(ls -t /run/WSL/*_interop | head -1)

    systemctl --user start syncthing || exit
    cd /mnt/c || exit
    WSL_INTEROP=$interop "$cmd" /c start "" "$url"
EOF
}

### COMPLETION & EXTERNAL SOURCES -------------------------------------------

if [ -f ~/.bash_aliases ]; then
  # shellcheck source=/dev/null
  . ~/.bash_aliases
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# shellcheck source=/dev/null
[ -f ~/.secrets ] && source ~/.secrets

[[ ! ${BLE_VERSION-} ]] || ble-attach
