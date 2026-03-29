### INTERACTIVE CHECK -------------------------------------------------------

case $- in
    *i*) ;;
      *) return;;
esac

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
shopt -s nocaseglob

set -o noclobber

### READLINE ----------------------------------------------------------------

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous off'
bind 'set mark-symlinked-directories on'

### PATH --------------------------------------------------------------------

export PNPM_HOME="/home/julien/.local/share/pnpm"

case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

### PROMPT ------------------------------------------------------------------

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt

case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

### VENV PROMPT FIX (Positron shell integration workaround) -----------------

export VIRTUAL_ENV_DISABLE_PROMPT=1

__base_ps1="$PS1"

__fix_venv_prompt() {
    if [ -n "$VIRTUAL_ENV" ]; then
        PS1="(${VIRTUAL_ENV_PROMPT:-$(basename "$VIRTUAL_ENV")}) $__base_ps1"
    else
        PS1="$__base_ps1"
    fi
}

PROMPT_COMMAND="__fix_venv_prompt; history -a"

### COLORS ------------------------------------------------------------------

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

### PAGER -------------------------------------------------------------------

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

### ALIASES -----------------------------------------------------------------

alias softup='sudo apt update && sudo apt full-upgrade && sudo apt autoremove && sudo apt clean && sudo snap refresh'
alias hardup='sudo journalctl --vacuum-time=7d && snap list --all | awk "/disabled/{print \$1, \$3}" | while read name rev; do sudo snap remove "$name" --revision="$rev"; done'
alias flatup='flatpak update -y && flatpak uninstall --unused -y'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fd=fdfind
alias qp='rm -rf .quarto; quarto preview'
alias yolo='git add . && git commit -m "." && git push'

### COMPLETION & EXTERNAL SOURCES -------------------------------------------

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

[ -f ~/.secrets ] && source ~/.secrets
