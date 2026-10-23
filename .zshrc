# ~/.zshrc - Kali-inspired, WSL-friendly zsh setup.
# Designed to be readable, fast enough for daily use, and easy to publish.

# ============================================================================
# Feature Toggles
# ============================================================================

ENABLE_GIT_INFO="Y"
ENABLE_GIT_OPERATIONS="Y"
ENABLE_TIMESTAMP="Y"
ENABLE_SYSTEM_LOAD="Y"
ENABLE_VIRTUAL_ENV="Y"
ENABLE_PATH_SHORTENING="Y"
ENABLE_COMMAND_TIMER="Y"
ENABLE_EXIT_STATUS="Y"
ENABLE_IGNORE_HOME_GIT="N"
ENABLE_SMART_HISTORY="Y"
ENABLE_EXTENDED_GLOB="Y"
ENABLE_COMMAND_CORRECTION="N"
ENABLE_ARGUMENT_CORRECTION="N"
ENABLE_PERFORMANCE_DEBUG="N"
ENABLE_AUTOSUGGESTIONS="Y"
ENABLE_SYNTAX_HIGHLIGHTING="Y"

# ============================================================================
# Tuning
# ============================================================================

GIT_CACHE_TIMEOUT=3
GIT_STATUS_TIMEOUT=0.35
# 0: use the space left on the first prompt line; positive values add a cap.
PATH_MAX_LENGTH=0
HISTORY_SIZE=5000
HISTORY_SAVE_SIZE=10000
COMMAND_TIMER_THRESHOLD=3

# Keep the prompt "Kali-like" without hardcoding the Kali ㉿ glyph.
# Robust defaults:
#   @  - safest across fonts
#   ㉿ - Kali-like, but font-dependent
#   ◉  - compact visual badge, also font-dependent
PROMPT_HOST_SYMBOL="@"
PROMPT_ROOT_SYMBOL="#"
PROMPT_USER_SYMBOL="$"

GIT_DIRTY_SYMBOL="*"
GIT_STAGED_SYMBOL="+"
GIT_UNTRACKED_SYMBOL="?"
GIT_STASH_SYMBOL="$"
GIT_TIMEOUT_SYMBOL="~"
GIT_ERROR_SYMBOL="!"

# ============================================================================
# Early Return For Non-interactive Shells
# ============================================================================

case $- in
    *i*) ;;
      *) return ;;
esac

# Initialization choices belong here; final personal overrides load near the end.
[[ -r "${HOME}/.zsh_config" ]] && source "${HOME}/.zsh_config"

# ============================================================================
# Colors
# ============================================================================

autoload -Uz colors && colors

COLOR_GREEN="%F{green}"
COLOR_CYAN="%F{cyan}"
COLOR_WHITE="%F{white}"
COLOR_ORANGE="%F{208}"
COLOR_RED="%F{red}"
COLOR_YELLOW="%F{yellow}"
COLOR_BLUE="%F{blue}"
COLOR_MAGENTA="%F{magenta}"
COLOR_DIM="%F{244}"
COLOR_RESET="%f"

# ============================================================================
# Core Shell Behavior
# ============================================================================

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=$HISTORY_SIZE
SAVEHIST=$HISTORY_SAVE_SIZE

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_VERIFY
setopt HIST_REDUCE_BLANKS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_SPACE

setopt CHECK_JOBS
setopt AUTO_MENU
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
# Prompt components are assembled by functions, not evaluated as shell code.
unsetopt PROMPT_SUBST

[[ "$ENABLE_EXTENDED_GLOB" == "Y" ]] && setopt EXTENDED_GLOB
[[ "$ENABLE_COMMAND_CORRECTION" == "Y" ]] && setopt CORRECT
[[ "$ENABLE_ARGUMENT_CORRECTION" == "Y" ]] && setopt CORRECT_ALL

command -v lesspipe >/dev/null 2>&1 && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================================================
# Completion
# ============================================================================

[[ -d "${HOME}/.zsh/cache" ]] || mkdir -p "${HOME}/.zsh/cache"

autoload -Uz compinit
if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format "${COLOR_DIM}Completing %d${COLOR_RESET}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' verbose true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${HOME}/.zsh/cache"
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w -w'

# ============================================================================
# Aliases And Small Helpers
# ============================================================================

if [[ -x /usr/bin/dircolors ]]; then
    if [[ -r "${HOME}/.dircolors" ]]; then
        eval "$(dircolors -b "${HOME}/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
    export LS_COLORS="${LS_COLORS}:ow=30;44:"
fi

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias aptup='pkgup'

mkcd() {
    [[ $# -eq 1 && -n "$1" ]] || { print -u2 'usage: mkcd DIRECTORY'; return 2; }
    mkdir -p -- "$1" && cd -- "$1"
}

# Detect the native package family, not whichever foreign CLI happens to exist.
_pkg_manager() {
    local ID ID_LIKE
    [[ -r /etc/os-release ]] || return 1
    source /etc/os-release
    case " $ID $ID_LIKE " in
        *' debian '*|*' ubuntu '*) command -v apt >/dev/null && { print apt; return; } ;;
        *' fedora '*|*' rhel '*|*' centos '*) command -v dnf >/dev/null && { print dnf; return; } ;;
    esac
    print -u2 'package helpers: unsupported package manager'
    return 1
}

pkgup() {
    [[ $# -eq 0 ]] || { print -u2 'usage: pkgup'; return 2; }
    local manager
    manager=$(_pkg_manager) || return
    case "$manager" in
        apt) print 'APT: refresh package lists, then upgrade'; sudo apt update && sudo apt upgrade ;;
        dnf) print 'DNF: refresh metadata and upgrade'; sudo dnf upgrade --refresh ;;
    esac
}

pkgclean() {
    [[ $# -eq 0 ]] || { print -u2 'usage: pkgclean'; return 2; }
    local manager
    manager=$(_pkg_manager) || return
    print 'Remove unused dependencies (review the native confirmation), then clear downloaded packages.'
    case "$manager" in
        apt) sudo apt autoremove && sudo apt clean ;;
        dnf) sudo dnf autoremove && sudo dnf clean packages ;;
    esac
}

_extract_need() {
    command -v "$1" >/dev/null 2>&1 && return 0
    local package="$1" manager
    case "$1" in
        gunzip|gzip) package=gzip ;;
        bunzip2|bzip2) package=bzip2 ;;
        unxz|xz) package=xz; [[ $(_pkg_manager 2>/dev/null) == apt ]] && package=xz-utils ;;
    esac
    manager=$(_pkg_manager 2>/dev/null)
    print -u2 -r -- "extract: missing $1 (package: $package)"
    [[ -n "$manager" ]] && print -u2 -r -- "Install with: sudo $manager install $package"
    return 1
}

extract() {
    [[ $# -eq 1 ]] || { print -u2 'usage: extract ARCHIVE'; return 2; }
    [[ -f "$1" ]] || { print -u2 -r -- "extract: file not found: $1"; return 1; }
    local archive="${1:a}" tool
    case "$archive" in
        *.tar.bz2|*.tbz2) tool=bzip2 ;;
        *.tar.gz|*.tgz) tool=gzip ;;
        *.tar.xz) tool=xz ;;
    esac
    [[ -z "$tool" ]] || _extract_need "$tool" || return 1
    case "$archive" in
        *.tar.bz2|*.tar.gz|*.tar.xz|*.tar|*.tbz2|*.tgz)
            _extract_need tar && command tar --extract --keep-old-files --file "$archive" ;;
        *.zip) _extract_need unzip && command unzip -n "$archive" ;;
        *.gz)  _extract_need gunzip && command gunzip -k -- "$archive" ;;
        *.bz2) _extract_need bunzip2 && command bunzip2 -k -- "$archive" ;;
        *.xz)  _extract_need unxz && command unxz -k -- "$archive" ;;
        *) print -u2 -r -- "extract: unsupported archive: $1"; return 1 ;;
    esac
    local rc=$?
    (( rc == 0 )) && echo "extract: extracted $1 to $PWD"
    return $rc
}

# ============================================================================
# Runtime State
# ============================================================================

typeset -g _git_cache_info=""
typeset -g _git_cache_pwd=""
typeset -g _git_cache_head=""
typeset -g _git_cache_time=0
typeset -g _git_info_out=""

typeset -g _load_cache=""
typeset -g _load_cache_time=0
typeset -g _load_info_out=""

typeset -g _path_info_out=""
typeset -g _prompt_prefix=""
typeset -g _prompt_suffix=""

typeset -g _last_command_start=0
typeset -g _last_command_duration=""
typeset -g _last_exit_status=0

zmodload zsh/datetime 2>/dev/null || true

# ============================================================================
# Prompt Components
# ============================================================================

_load_threshold() {
    local cores
    cores=$(command -v nproc >/dev/null 2>&1 && nproc || echo 1)
    print -r -- $(( cores * 0.7 ))
}

get_system_load() {
    _load_info_out=""
    [[ "$ENABLE_SYSTEM_LOAD" != "Y" ]] && return

    local current_time=${EPOCHSECONDS:-$(date +%s)}
    local cache_age=$((current_time - _load_cache_time))
    if [[ $_load_cache_time -gt 0 && $cache_age -ge 0 && $cache_age -lt 5 ]]; then
        _load_info_out="$_load_cache"
        return
    fi

    local load_avg threshold ignored
    [[ -r /proc/loadavg ]] || return
    read -r load_avg ignored < /proc/loadavg || return
    threshold=$(_load_threshold)

    if (( load_avg > threshold )); then
        _load_cache="${COLOR_RED}load:$(printf '%.1f' "$load_avg")${COLOR_RESET}"
    else
        _load_cache=""
    fi

    _load_cache_time=$current_time
    _load_info_out="$_load_cache"
}

get_timestamp() {
    [[ "$ENABLE_TIMESTAMP" == "Y" ]] && date +"%Y-%m-%d %H:%M:%S"
}

get_virtual_env() {
    [[ "$ENABLE_VIRTUAL_ENV" != "Y" ]] && return

    local venv_name=""
    if [[ -n "$VIRTUAL_ENV" && -d "$VIRTUAL_ENV" ]]; then
        venv_name=$(basename "$VIRTUAL_ENV")
    elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        venv_name="conda:${CONDA_DEFAULT_ENV}"
    elif [[ -n "$PIPENV_ACTIVE" ]]; then
        venv_name="pipenv"
    fi

    [[ -n "$venv_name" ]] && print -r -- "${COLOR_CYAN}${venv_name//\%/%%}${COLOR_RESET}"
}

is_git_repo() {
    [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" == true ]]
}

should_show_git_info() {
    is_git_repo || return 1

    if [[ "$ENABLE_IGNORE_HOME_GIT" == "Y" ]]; then
        local top
        top=$(command git rev-parse --show-toplevel 2>/dev/null) || return 1
        [[ "$top" == "$HOME" ]] && return 1
    fi

    return 0
}

get_git_operation_status() {
    [[ "$ENABLE_GIT_OPERATIONS" != "Y" ]] && return

    local git_dir operations=""
    git_dir=$(command git rev-parse --git-dir 2>/dev/null) || return

    [[ -f "$git_dir/MERGE_HEAD" ]] && operations+="MERGE "
    [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]] && operations+="REBASE "
    [[ -f "$git_dir/CHERRY_PICK_HEAD" ]] && operations+="CHERRY-PICK "
    [[ -f "$git_dir/REVERT_HEAD" ]] && operations+="REVERT "
    [[ -f "$git_dir/BISECT_LOG" ]] && operations+="BISECT "

    [[ -n "$operations" ]] && echo "${COLOR_RED}[${operations% }]${COLOR_RESET} "
}

_git_status_porcelain() {
    if command -v timeout >/dev/null 2>&1; then
        command timeout "$GIT_STATUS_TIMEOUT" git status --porcelain=v1 2>/dev/null
    else
        command git status --porcelain=v1 2>/dev/null
    fi
}

get_git_info() {
    _git_info_out=""
    [[ "$ENABLE_GIT_INFO" != "Y" ]] && return
    should_show_git_info || return

    local current_pwd="$PWD"
    local current_time=${EPOCHSECONDS:-$(date +%s)}
    local git_head cache_age

    git_head="$(command git symbolic-ref -q HEAD 2>/dev/null):$(command git rev-parse --verify HEAD 2>/dev/null)"
    cache_age=$((current_time - _git_cache_time))

    if [[ "$_git_cache_pwd" == "$current_pwd" &&
          "$_git_cache_head" == "$git_head" &&
          $cache_age -ge 0 && $cache_age -lt $GIT_CACHE_TIMEOUT &&
          -n "$_git_cache_info" ]]; then
        _git_info_out="$_git_cache_info"
        return
    fi

    local branch
    if ! branch=$(command git symbolic-ref --short HEAD 2>/dev/null); then
        if branch=$(command git describe --tags --exact-match HEAD 2>/dev/null); then
            branch="tag:${branch}"
        else
            branch=$(command git rev-parse --short HEAD 2>/dev/null) || branch="unknown"
        fi
    fi

    local git_status="" status_output porcelain_rc
    status_output=$(_git_status_porcelain)
    porcelain_rc=$?

    if [[ $porcelain_rc -eq 124 ]]; then
        git_status+="$GIT_TIMEOUT_SYMBOL"
    elif [[ $porcelain_rc -ne 0 ]]; then
        git_status+="$GIT_ERROR_SYMBOL"
    elif [[ -n "$status_output" ]]; then
        print -r -- "$status_output" | command grep -q '^[ MADRCU][MADRCU]' && git_status+="$GIT_DIRTY_SYMBOL"
        print -r -- "$status_output" | command grep -q '^[MADRCU]' && git_status+="$GIT_STAGED_SYMBOL"
        print -r -- "$status_output" | command grep -q '^??' && git_status+="$GIT_UNTRACKED_SYMBOL"
    fi

    command git rev-parse --verify refs/stash >/dev/null 2>&1 && git_status+="$GIT_STASH_SYMBOL"

    local upstream ahead_behind ahead behind
    if upstream=$(command git rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
        ahead_behind=$(command git rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)
        if [[ -n "$ahead_behind" ]]; then
            ahead=${ahead_behind%%$'\t'*}
            behind=${ahead_behind##*$'\t'}
            [[ "$ahead" -gt 0 ]] && git_status+="↑${ahead}"
            [[ "$behind" -gt 0 ]] && git_status+="↓${behind}"
        fi
    fi

    local operations result
    branch="${branch//\%/%%}"
    operations=$(get_git_operation_status)
    if [[ -n "$git_status" ]]; then
        result="${operations}${COLOR_ORANGE}${branch}${COLOR_RESET} ${git_status}"
    else
        result="${operations}${COLOR_ORANGE}${branch}${COLOR_RESET}"
    fi

    _git_cache_info="$result"
    _git_cache_pwd="$current_pwd"
    _git_cache_head="$git_head"
    _git_cache_time=$current_time

    _git_info_out="$result"
}

_shorten_path_components() {
    local full="$1" max_len="$2"
    local leading="" body=""
    local -a parts

    if [[ "$full" == "~" ]]; then
        print -r -- "~"
        return
    elif [[ "$full" == "/" ]]; then
        print -r -- "/"
        return
    elif [[ "$full" == '~/'* ]]; then
        body="${full#\~/}"
        parts=("~" "${(@s:/:)body}")
    elif [[ "$full" == /* ]]; then
        leading="/"
        body="${full#/}"
        parts=("${(@s:/:)body}")
    else
        parts=("${(@s:/:)full}")
    fi

    local n=${#parts}
    if (( n <= 1 )); then
        print -r -- "${leading}${(j:/:)parts}"
        return
    fi

    local ellipsis="…"
    local head_count=1 tail_count=1
    local head_joined tail_joined candidate_len

    while (( head_count + tail_count < n )); do
        tail_joined="${(j:/:)parts[$((n - tail_count)),$n]}"
        candidate_len=$(( ${(m)#leading} + ${(m)#parts[1]} + 3 + ${(m)#tail_joined} ))
        (( candidate_len > max_len )) && break
        (( tail_count++ ))
    done

    while (( head_count + tail_count < n )); do
        head_joined="${(j:/:)parts[1,$((head_count + 1))]}"
        tail_joined="${(j:/:)parts[$((n - tail_count + 1)),$n]}"
        candidate_len=$(( ${(m)#leading} + ${(m)#head_joined} + 3 + ${(m)#tail_joined} ))
        (( candidate_len > max_len )) && break
        (( head_count++ ))
    done

    if (( head_count + tail_count >= n )); then
        print -r -- "${leading}${(j:/:)parts}"
        return
    fi

    head_joined="${(j:/:)parts[1,$head_count]}"
    tail_joined="${(j:/:)parts[$((n - tail_count + 1)),$n]}"
    print -r -- "${leading}${head_joined}/${ellipsis}/${tail_joined}"
}

get_shortened_path() {
    _path_info_out=""
    [[ "$ENABLE_PATH_SHORTENING" != "Y" ]] && { _path_info_out="%~"; return; }

    local max_len=${1:-${COLUMNS:-64}}
    (( max_len > 0 )) || max_len=64
    (( PATH_MAX_LENGTH > 0 && PATH_MAX_LENGTH < max_len )) && max_len=$PATH_MAX_LENGTH

    local expanded_path="${(%)${:-%~}}"

    local result="$expanded_path"
    if (( ${(m)#expanded_path} > max_len )); then
        result=$(_shorten_path_components "$expanded_path" "$max_len")
    fi

    _path_info_out="${result//\%/%%}"
}

get_exit_status() {
    local code="$1"
    [[ "$ENABLE_EXIT_STATUS" == "Y" && "$code" -ne 0 ]] && echo "${COLOR_RED}exit:${code}${COLOR_RESET}"
}

get_command_duration() {
    [[ "$ENABLE_COMMAND_TIMER" == "Y" && -n "$_last_command_duration" ]] && echo "${COLOR_DIM}${_last_command_duration}${COLOR_RESET}"
}

_format_duration() {
    local elapsed="$1"
    if (( elapsed >= 3600 )); then
        printf '%dh%02dm%02ds' $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))
    elif (( elapsed >= 60 )); then
        printf '%dm%02ds' $((elapsed/60)) $((elapsed%60))
    else
        printf '%ds' "$elapsed"
    fi
}

# ============================================================================
# Prompt
# ============================================================================

_render_zsh_prompt() {
    setopt localoptions extendedglob
    local fixed="${(%)_prompt_prefix}${(%)_prompt_suffix}"
    # Remove SGR colour escapes before measuring terminal display cells.
    fixed="${fixed//$'\e'\[[0-9;]##m/}"
    local available=$(( ${COLUMNS:-80} - ${(m)#fixed} - 3 - 1 ))
    (( available < 1 )) && available=1
    get_shortened_path "$available"
    PROMPT="${_prompt_prefix}${COLOR_GREEN}-[${COLOR_WHITE}${_path_info_out}${COLOR_GREEN}]${_prompt_suffix}${COLOR_RESET}
${COLOR_GREEN}└─${COLOR_RESET}${COLOR_CYAN}%(!.${PROMPT_ROOT_SYMBOL}.${PROMPT_USER_SYMBOL})${COLOR_RESET} "
}

set_zsh_prompt() {
    local last_status="${_last_exit_status:-$?}"
    local virtual_env git_info timestamp status_info duration_info system_load
    local user_host

    virtual_env=$(get_virtual_env)
    get_git_info; git_info="$_git_info_out"
    timestamp=$(get_timestamp)
    status_info=$(get_exit_status "$last_status")
    duration_info=$(get_command_duration)
    get_system_load; system_load="$_load_info_out"

    user_host="${COLOR_CYAN}%n${PROMPT_HOST_SYMBOL}%m${COLOR_RESET}"
    _prompt_prefix="${COLOR_GREEN}┌──(${COLOR_RESET}${user_host}${COLOR_GREEN})"
    [[ -n "$virtual_env" ]] && _prompt_prefix+="-[${virtual_env}${COLOR_GREEN}]"
    _prompt_suffix=""
    [[ -n "$git_info" ]] && _prompt_suffix+="-[${git_info}${COLOR_GREEN}]"
    [[ -n "$timestamp" ]] && _prompt_suffix+="-[${COLOR_WHITE}${timestamp}${COLOR_GREEN}]"
    [[ -n "$duration_info" ]] && _prompt_suffix+="-[${duration_info}${COLOR_GREEN}]"
    [[ -n "$system_load" ]] && _prompt_suffix+="-[${system_load}${COLOR_GREEN}]"
    [[ -n "$status_info" ]] && _prompt_suffix+="-[${status_info}${COLOR_GREEN}]"
    _render_zsh_prompt
}

_preexec_timer() {
    _last_command_start=${EPOCHSECONDS:-$(date +%s)}
    _last_command_duration=""
}

_precmd_timer() {
    local now elapsed
    now=${EPOCHSECONDS:-$(date +%s)}
    if [[ "$ENABLE_COMMAND_TIMER" == "Y" && "$_last_command_start" -gt 0 ]]; then
        elapsed=$((now - _last_command_start))
        if (( elapsed >= COMMAND_TIMER_THRESHOLD )); then
            _last_command_duration=$(_format_duration "$elapsed")
        else
            _last_command_duration=""
        fi
    fi
    _last_command_start=0
}

_precmd_capture_status() {
    _last_exit_status=$?
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _preexec_timer
add-zsh-hook precmd _precmd_capture_status
add-zsh-hook precmd _precmd_timer
add-zsh-hook precmd set_zsh_prompt

# ============================================================================
# Key Bindings
# ============================================================================

bindkey -e
bindkey ' ' magic-space
bindkey '^U' backward-kill-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^R' history-incremental-search-backward

if [[ "$ENABLE_SMART_HISTORY" == "Y" ]]; then
    bindkey '^[[A' history-search-backward
    bindkey '^[[B' history-search-forward
fi

# ============================================================================
# Plugins
# ============================================================================
# Sourced last (after completion, aliases, key bindings) so
# zsh-syntax-highlighting wraps every widget already defined by then.

# Final user overrides precede plugins so widget wrapping sees custom bindings.
[[ -r "${HOME}/.zsh_aliases" ]] && source "${HOME}/.zsh_aliases"
[[ -r "${HOME}/.zsh_local" ]] && source "${HOME}/.zsh_local"

if [[ "$ENABLE_AUTOSUGGESTIONS" == Y && -f "${HOME}/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${HOME}/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

if [[ "$ENABLE_SYNTAX_HIGHLIGHTING" == Y && -f "${HOME}/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "${HOME}/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ============================================================================
# Debug
# ============================================================================

if [[ "$ENABLE_PERFORMANCE_DEBUG" == "Y" ]]; then
    zmodload zsh/zprof
    benchmark_prompt() {
        echo "Benchmarking prompt generation..."
        time (for i in {1..20}; do set_zsh_prompt; done)
    }
    echo "Zsh performance debugging enabled. Commands: benchmark_prompt, zprof"
fi

set_zsh_prompt
