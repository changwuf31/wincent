#
# Global
#

# Create a hash table for globally stashing variables without polluting main
# scope with a bunch of identifiers.
typeset -A __WINCENT

__WINCENT[ITALIC_ON]=$'\e[3m'
__WINCENT[ITALIC_OFF]=$'\e[23m'

#
# Teh H4xx
#

if [ "$(uname)" = "Darwin" ]; then
  # Suppress unwanted Homebrew-installed stuff.
  if [ -e /usr/local/share/zsh/site-functions/_git ]; then
    mv -f /usr/local/share/zsh/site-functions/{,disabled.}_git
  fi

  # Set 60 fps key repeat rate
  #
  # Equivalent to the fatest rate acheivable with:
  #
  #     defaults write NSGlobalDomain KeyRepeat -int 1
  #
  # But doesn't require a logout and will get restored every time we open a
  # shell (for example, if somebody manipulates the slider in the UI).
  #
  # Fastest rate available from UI corresponds to:
  #
  #     defaults write NSGlobalDomain KeyRepeat -int 2
  #
  # Slowest rate available from UI corresponds to:
  #
  #     defaults write NSGlobalDomain KeyRepeat -int 120
  #
  # Values at each slider position in UI, from slowest to fastest:
  #
  # - 120 -> 2 seconds (ie. .5 fps)
  # - 90 -> 1.5 seconds (ie .6666 fps)
  # - 60 -> 1 second (ie 1 fps)
  # - 30 -> 0.5 seconds (ie. 2 fps)
  # - 12 -> 0.2 seconds (ie. 5 fps)
  # - 6 -> 0.1 seconds (ie. 10 fps)
  # - 2 -> 0.03333 seconds (ie. 30 fps)
  #
  # See: https://github.com/mathiasbynens/dotfiles/issues/687
  #
  if command -v dry &> /dev/null; then
    dry 0.0166666666667 > /dev/null
  fi
fi

#
# Completion
#

fpath=($HOME/.zsh/completions $fpath)

autoload -U compinit
compinit -u

# Make completion:
# - Try exact (case-sensitive) match first.
# - Then fall back to case-insensitive.
# - Accept abbreviations after . or _ or - (ie. f.b -> foo.bar).
# - Substring complete (ie. bar -> foobar).
zstyle ':completion:*' matcher-list '' '+m:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}' '+m:{_-}={-_}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Colorize completions using default `ls` colors.
zstyle ':completion:*' list-colors ''

# Allow completion of ..<Tab> to ../ and beyond.
zstyle -e ':completion:*' special-dirs '[[ $PREFIX = (../)#(..) ]] && reply=(..)'

# $CDPATH is overpowered (can allow us to jump to 100s of directories) so tends
# to dominate completion; exclude path-directories from the tag-order so that
# they will only be used as a fallback if no completions are found.
zstyle ':completion:*:complete:(cd|pushd):*' tag-order 'local-directories named-directories'

# Categorize completion suggestions with headings:
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format %F{default}%B%{$__WINCENT[ITALIC_ON]%}--- %d ---%{$__WINCENT[ITALIC_OFF]%}%b%f

# Enable keyboard navigation of completions in menu
# (not just tab/shift-tab but cursor keys as well):
zstyle ':completion:*' menu select

#
# Correction
#

# exceptions to auto-correction
alias bundle='nocorrect bundle'
alias cabal='nocorrect cabal'
alias man='nocorrect man'
alias mkdir='nocorrect mkdir'
alias mv='nocorrect mv'
alias stack='nocorrect stack'
alias sudo='nocorrect sudo'

#
# Prompt
#

autoload -U colors
colors

# http://zsh.sourceforge.net/Doc/Release/User-Contributions.html
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git hg
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' disable-patterns "${(b)HOME}/code/portal(|-ee)(|/*)"
zstyle ':vcs_info:*' stagedstr "%F{green}●%f" # default 'S'
zstyle ':vcs_info:*' unstagedstr "%F{red}●%f" # default 'U'
zstyle ':vcs_info:*' use-simple true
zstyle ':vcs_info:git+set-message:*' hooks git-untracked
zstyle ':vcs_info:git*:*' formats '[%b%m%c%u] ' # default ' (%s)-[%b]%c%u-'
zstyle ':vcs_info:git*:*' actionformats '[%b|%a%m%c%u] ' # default ' (%s)-[%b|%a]%c%u-'
zstyle ':vcs_info:hg*:*' formats '[%m%b] '
zstyle ':vcs_info:hg*:*' actionformats '[%b|%a%m] '
zstyle ':vcs_info:hg*:*' branchformat '%b'
zstyle ':vcs_info:hg*:*' get-bookmarks true
zstyle ':vcs_info:hg*:*' get-revision true
zstyle ':vcs_info:hg*:*' get-mq false
zstyle ':vcs_info:hg*+gen-hg-bookmark-string:*' hooks hg-bookmarks
zstyle ':vcs_info:hg*+set-message:*' hooks hg-message

function +vi-hg-bookmarks() {
  emulate -L zsh
  if [[ -n "${hook_com[hg-active-bookmark]}" ]]; then
    hook_com[hg-bookmark-string]="${(Mj:,:)@}"
    ret=1
  fi
}

function +vi-hg-message() {
  emulate -L zsh

  # Suppress hg branch display if we can display a bookmark instead.
  if [[ -n "${hook_com[misc]}" ]]; then
    hook_com[branch]=''
  fi
  return 0
}

function +vi-git-untracked() {
  emulate -L zsh
  if [[ -n $(git ls-files --exclude-standard --others 2> /dev/null) ]]; then
    hook_com[unstaged]+="%F{blue}●%f"
  fi
}

RPROMPT_BASE="\${vcs_info_msg_0_}%F{blue}%~%f"
setopt PROMPT_SUBST

# Anonymous function to avoid leaking variables.
function () {
  # Check for tmux by looking at $TERM, because $TMUX won't be propagated to any
  # nested sudo shells but $TERM will.
  local TMUXING=$([[ "$TERM" =~ "tmux" ]] && echo tmux)
  if [ -n "$TMUXING" -a -n "$TMUX" ]; then
    # In a a tmux session created in a non-root or root shell.
    local LVL=$(($SHLVL - 1))
  else
    # Either in a root shell created inside a non-root tmux session,
    # or not in a tmux session.
    local LVL=$SHLVL
  fi
  if [[ $EUID -eq 0 ]]; then
    local SUFFIX='%F{yellow}%n%f'$(printf '%%F{yellow}\u276f%.0s%%f' {1..$LVL})
  else
    local SUFFIX=$(printf '%%F{red}\u276f%.0s%%f' {1..$LVL})
  fi
  export PS1="%F{green}${SSH_TTY:+%n@%m}%f%B${SSH_TTY:+:}%b%F{blue}%B%1~%b%F{yellow}%B%(1j.*.)%(?..!)%b%f %B${SUFFIX}%b "
  if [[ -n "$TMUXING" ]]; then
    # Outside tmux, ZLE_RPROMPT_INDENT ends up eating the space after PS1, and
    # prompt still gets corrupted even if we add an extra space to compensate.
    export ZLE_RPROMPT_INDENT=0
  fi
}

export RPROMPT=$RPROMPT_BASE
export SPROMPT="zsh: correct %F{red}'%R'%f to %F{red}'%r'%f [%B%Uy%u%bes, %B%Un%u%bo, %B%Ue%u%bdit, %B%Ua%u%bbort]? "

#
# History
#

export HISTSIZE=100000
export HISTFILE="$HOME/.history"
export SAVEHIST=$HISTSIZE

#
# Options
#

setopt AUTO_CD                 # [default] .. is shortcut for cd .. (etc)
setopt AUTO_PARAM_SLASH        # tab completing directory appends a slash
setopt AUTO_PUSHD              # [default] cd automatically pushes old dir onto dir stack
setopt AUTO_RESUME             # allow simple commands to resume backgrounded jobs
setopt CLOBBER                 # allow clobbering with >, no need to use >!
unsetopt CORRECT                 # [default] command auto-correction
unsetopt CORRECT_ALL             # [default] argument auto-correction
setopt NO_FLOW_CONTROL         # disable start (C-s) and stop (C-q) characters
setopt NO_HIST_IGNORE_ALL_DUPS # don't filter duplicates from history
setopt NO_HIST_IGNORE_DUPS     # don't filter contiguous duplicates from history
setopt HIST_FIND_NO_DUPS       # don't show dupes when searching
setopt HIST_IGNORE_SPACE       # [default] don't record commands starting with a space
setopt HIST_VERIFY             # confirm history expansion (!$, !!, !foo)
#setopt IGNORE_EOF              # [default] prevent accidental C-d from exiting shell
setopt INTERACTIVE_COMMENTS    # [default] allow comments, even in interactive shells
setopt LIST_PACKED             # make completion lists more densely packed
setopt MENU_COMPLETE           # auto-insert first possible ambiguous completion
setopt NO_NOMATCH              # [default] unmatched patterns are left unchanged
setopt PRINT_EXIT_VALUE        # [default] for non-zero exit status
setopt PUSHD_IGNORE_DUPS       # don't push multiple copies of same dir onto stack
setopt PUSHD_SILENT            # [default] don't print dir stack after pushing/popping
setopt SHARE_HISTORY           # share history across shells

#
# Bindings
#
# create a zkbd compatible hash;
# to add other keys to this hash, see: man 5 terminfo
typeset -g -A key

# Finally, make sure the terminal is in application mode, when zle is
# active. Only then are the values from $terminfo valid.
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	autoload -Uz add-zle-hook-widget
	function zle_application_mode_start {
		echoti smkx
	}
	function zle_application_mode_stop {
		echoti rmkx
	}
	add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
	add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

bindkey -e # emacs bindings, set to -v for vi bindings

# Use "cbt" capability ("back_tab", as per `man terminfo`), if we have it:
if tput cbt &> /dev/null; then
  bindkey "$(tput cbt)" reverse-menu-complete # make Shift-tab go to previous completion
fi

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "\e[A" history-beginning-search-backward-end  # cursor up
bindkey "\e[B" history-beginning-search-forward-end   # cursor down

autoload -U select-word-style
select-word-style bash # only alphanumeric chars are considered WORDCHARS

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^x' edit-command-line

bindkey ' ' magic-space # do history expansion on space

# Replace standard history-incremental-search-{backward,forward} bindings.
# These are the same but permit patterns (eg. a*b) to be used.
bindkey "^r" history-incremental-pattern-search-backward
bindkey "^s" history-incremental-pattern-search-forward

# Make CTRL-Z background things and unbackground them.
function fg-bg() {
  if [[ $#BUFFER -eq 0 ]]; then
    fg
  else
    zle push-input
  fi
}
zle -N fg-bg
bindkey '^Z' fg-bg

#
# ZPM
#
if [[ ! -f ~/.zpm/zpm.zsh ]]; then
  git clone --recursive https://github.com/zpm-zsh/zpm ~/.zpm
fi
source ~/.zpm/zpm.zsh

#
# Other
#

source $HOME/.zsh/aliases
source $HOME/.zsh/common
source $HOME/.zsh/colors
source $HOME/.zsh/exports
source $HOME/.zsh/functions
source $HOME/.zsh/hash
source $HOME/.zsh/path
source $HOME/.zsh/vars

#
# Third-party
#

#CHRUBY=/usr/local/share/chruby
#test -e "$CHRUBY/chruby.sh" && source "$CHRUBY/chruby.sh"
#test -e "$CHRUBY/auto.sh" && source "$CHRUBY/auto.sh"

# Skim

# test -e "$HOME/.zsh/skim/shell/key-bindings.zsh" && source "$HOME/.zsh/skim/shell/key-bindings.zsh"
test -e "$HOME/.zsh/skim/shell/completion.zsh" && source "$HOME/.zsh/skim/shell/completion.zsh"

#
# Hooks
#

autoload -U add-zsh-hook
if [ -f /usr/bin/direnv ]; then
  eval "$(direnv hook zsh)"
fi

function -set-tab-and-window-title() {
  emulate -L zsh
  local CMD="${1:gs/$/\\$}"
  print -Pn "\e]0;$CMD:q\a"
}

# $HISTCMD (the current history event number) is shared across all shells
# (due to SHARE_HISTORY). Maintain this local variable to count the number of
# commands run in this specific shell.
HISTCMD_LOCAL=0

# Executed before displaying prompt.
function -update-window-title-precmd() {
  emulate -L zsh
  if [[ HISTCMD_LOCAL -eq 0 ]]; then
    # About to display prompt for the first time; nothing interesting to show in
    # the history. Show $PWD.
    -set-tab-and-window-title "$(basename $PWD)"
  else
    local LAST=$(history | tail -1 | awk '{print $2}')
    if [ -n "$TMUX" ]; then
      # Inside tmux, just show the last command: tmux will prefix it with the
      # session name (for context).
      -set-tab-and-window-title "$LAST"
    else
      # Outside tmux, show $PWD (for context) followed by the last command.
      -set-tab-and-window-title "$(basename $PWD) > $LAST"
    fi
  fi
}
add-zsh-hook precmd -update-window-title-precmd

# Executed before executing a command: $2 is one-line (truncated) version of
# the command.
function -update-window-title-preexec() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  HISTCMD_LOCAL=$((++HISTCMD_LOCAL))

  # Skip ENV=settings, sudo, ssh; show first distinctive word of command;
  # mostly stolen from:
  #   https://github.com/robbyrussell/oh-my-zsh/blob/master/lib/termsupport.zsh
  local TRIMMED="${2[(wr)^(*=*|mosh|ssh|sudo)]}"
  if [ -n "$TMUX" ]; then
    # Inside tmux, show the running command: tmux will prefix it with the
    # session name (for context).
    -set-tab-and-window-title "$TRIMMED"
  else
    # Outside tmux, show $PWD (for context) followed by the running command.
    -set-tab-and-window-title "$(basename $PWD) > $TRIMMED"
  fi
}
add-zsh-hook preexec -update-window-title-preexec

typeset -F SECONDS
function -record-start-time() {
  emulate -L zsh
  ZSH_START_TIME=${ZSH_START_TIME:-$SECONDS}
}
add-zsh-hook preexec -record-start-time

function -report-start-time() {
  emulate -L zsh
  if [ $ZSH_START_TIME ]; then
    local DELTA=$(($SECONDS - $ZSH_START_TIME))
    local DAYS=$((~~($DELTA / 86400)))
    local HOURS=$((~~(($DELTA - $DAYS * 86400) / 3600)))
    local MINUTES=$((~~(($DELTA - $DAYS * 86400 - $HOURS * 3600) / 60)))
    local SECS=$(($DELTA - $DAYS * 86400 - $HOURS * 3600 - $MINUTES * 60))
    local ELAPSED=''
    test "$DAYS" != '0' && ELAPSED="${DAYS}d"
    test "$HOURS" != '0' && ELAPSED="${ELAPSED}${HOURS}h"
    test "$MINUTES" != '0' && ELAPSED="${ELAPSED}${MINUTES}m"
    if [ "$ELAPSED" = '' ]; then
      SECS="$(print -f "%.2f" $SECS)s"
    elif [ "$DAYS" != '0' ]; then
      SECS=''
    else
      SECS="$((~~$SECS))s"
    fi
    ELAPSED="${ELAPSED}${SECS}"
    export RPROMPT="%F{cyan}%{$__WINCENT[ITALIC_ON]%}${ELAPSED}%{$__WINCENT[ITALIC_OFF]%}%f $RPROMPT_BASE"
    unset ZSH_START_TIME
  else
    export RPROMPT="$RPROMPT_BASE"
  fi
}
add-zsh-hook precmd -report-start-time

add-zsh-hook precmd bounce

function -auto-ls-after-cd() {
  emulate -L zsh
  # Only in response to a user-initiated `cd`, not indirectly (eg. via another
  # function).
  if [ "$ZSH_EVAL_CONTEXT" = "toplevel:shfunc" ]; then
    ls -a
  fi
}
add-zsh-hook chpwd -auto-ls-after-cd

# Remember each command we run.
function -record-command() {
  __WINCENT[LAST_COMMAND]="$2"
}
add-zsh-hook preexec -record-command

# Update vcs_info (slow) after any command that probably changed it.
function -maybe-show-vcs-info() {
  local LAST="$__WINCENT[LAST_COMMAND]"

  # In case user just hit enter, overwrite LAST_COMMAND, because preexec
  # won't run and it will otherwise linger.
  __WINCENT[LAST_COMMAND]="<unset>"

  # Check first word; via:
  # http://tim.vanwerkhoven.org/post/2012/10/28/ZSH/Bash-string-manipulation
  case "$LAST[(w)1]" in
    cd|cp|git|rm|touch|mv|)
      vcs_info
      ;;
    *)
      ;;
  esac
}
add-zsh-hook precmd -maybe-show-vcs-info

# adds `cdr` command for navigating to recent directories
autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs

# enable menu-style completion for cdr
zstyle ':completion:*:*:cdr:*:*' menu selection

# fall through to cd if cdr is passed a non-recent dir as an argument
zstyle ':chpwd:*' recent-dirs-default true

# Local and host-specific overrides.

LOCAL_RC=$HOME/.zshrc.local
test -f $LOCAL_RC && source $LOCAL_RC

HOST_RC=$HOME/.zsh/host/$(hostname -s)
test -f $HOST_RC && source $HOST_RC

if [ $TILIX_ID ] || [ $VTE_VERSION ]; then
  source /etc/profile.d/vte.sh
fi

#
# Plug-ins
#

#source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=59'

# Uncomment this to get syntax highlighting:
#source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
if [ -f /home/shared/opt/todotxt/todo_completion ]; then
  source /home/shared/opt/todotxt/todo_completion
fi 

zpm load zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=59'
zpm load git,type:omz
zpm load kubectl,type:omz
zpm load zsh-users/zsh-syntax-highlighting

#
# /etc/motd
#

#if [ -e /etc/motd ]; then
#  if ! cmp -s $HOME/.hushlogin /etc/motd; then
#    tee $HOME/.hushlogin < /etc/motd
#  fi
#fi

if [ -n "$TMUX" ]; then
  bindkey -- "^[[1~" beginning-of-line
  bindkey -- "^[[4~" end-of-line
  bindkey -- "^[[2~" overwrite-mode
  bindkey -- "^[[3~" delete-char
else
  key[Home]="${terminfo[khome]}"
  key[End]="${terminfo[kend]}"
  key[Insert]="${terminfo[kich1]}"
  key[Backspace]="${terminfo[kbs]}"
  key[Delete]="${terminfo[kdch1]}"
  key[Up]="${terminfo[kcuu1]}"
  key[Down]="${terminfo[kcud1]}"
  key[Left]="${terminfo[kcub1]}"
  key[Right]="${terminfo[kcuf1]}"
  key[PageUp]="${terminfo[kpp]}"
  key[PageDown]="${terminfo[knp]}"
  key[ShiftTab]="${terminfo[kcbt]}"

  # setup key accordingly
  [[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"      beginning-of-line
  [[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"       end-of-line
  [[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"    overwrite-mode
  [[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}" backward-delete-char
  [[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"    delete-char
  [[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"        up-line-or-history
  [[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"      down-line-or-history
  [[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"      backward-char
  [[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"     forward-char
  [[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"    beginning-of-buffer-or-history
  [[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"  end-of-buffer-or-history
  [[ -n "${key[ShiftTab]}"  ]] && bindkey -- "${key[ShiftTab]}"  reverse-menu-complete

fi
  
bindkey '^[[1;5C' forward-word
bindkey '^[[C' forward-word

bindkey '^[[1;5D' backward-word
bindkey '^[[D' backward-word

bindkey '^[[3;5~' delete-word
bindkey '^H' backward-delete-word

# fix ssh completion
zstyle ':completion:*:ssh:*' hosts off
