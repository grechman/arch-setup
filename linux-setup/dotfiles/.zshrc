# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim
export PATH=$PATH:$HOME/go/bin
export ANTHROPIC_BASE_URL=http://127.0.0.1:18080
export CLAUDE_CODE_API_BASE_URL=http://127.0.0.1:18080

# Sandbox claude — routes through the sonnet-classifier proxy on :18081
# instead of the prod opus proxy on :18080. Drop-in replacement for `claude`.
claude-sandbox() {
  ANTHROPIC_BASE_URL=http://127.0.0.1:18081 \
  CLAUDE_CODE_API_BASE_URL=http://127.0.0.1:18081 \
  command claude "$@"
}
alias airpods='bluetoothctl connect F0:D3:1F:65:57:44'
alias airpods-off='bluetoothctl disconnect F0:D3:1F:65:57:44'
alias vim='nvim'

wallpaper-set() {
    if [[ -z "$1" ]]; then
        print -u2 "usage: wallpaper-set <path-to-image>"
        return 1
    fi
    local image_path="${1/#\~/$HOME}"
    image_path="${image_path:A}"
    if [[ ! -f "$image_path" ]]; then
        print -u2 "wallpaper-set: not a file: $image_path"
        return 1
    fi
    print -r -- "splash = false

wallpaper {
    monitor =
    path = $image_path
    fit_mode = cover
}" > ~/.config/hypr/hyprpaper.conf
    pkill hyprpaper 2>/dev/null
    sleep 0.3
    hyprpaper >/dev/null 2>&1 & disown
    print -- "wallpaper set: $image_path"
}
alias cc='claude --allow-dangerously-skip-permissions'
alias cca=' claude agents --dangerously-skip-permissions --model opus\[1m\]  --effort max'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export PATH=~/.npm-global/bin:$PATH

# tmux tabs: one shared `main` session with named windows.
# `reload-tabs` reopens the persistent session. `newtab <name>` adds a new tab.
# Inside tmux: switch with Alt+1..9, prev/next with Alt+h/Alt+l.
alias reload-tabs='tmux new -A -s main'
newtab() {
    if [[ -z "$1" ]]; then
        print -u2 "usage: newtab <name>"
        return 1
    fi
    local name="${(j:-:)@}"
    name="${name//[^A-Za-z0-9_-]/-}"
    if [[ -n "$TMUX" ]]; then
        tmux new-window -n "$name"
    elif tmux has-session -t main 2>/dev/null; then
        tmux new-window -t main: -n "$name"
        tmux attach -t main
    else
        tmux new-session -s main -n "$name"
    fi
}

# kill a tmux session by name; no args kills the whole server.
tmkill() {
    if [[ -z "$1" ]]; then
        tmux kill-server 2>/dev/null && print "tmux server killed"
    else
        tmux kill-session -t "$1"
    fi
}

# theme <name> | theme list | theme help
# Flips the system theme across hyprland borders, ghostty, waybar, rofi, GTK,
# KDE/Qt, and tmux.
# Implementation: rewrites the active `source = ...themes/X.conf` line in
# hyprland.conf, applies app colors directly, then runs `hyprctl reload` for
# compositor-side colors.
theme() {
    local name="$1"
    local hyprconf="$HOME/.config/hypr/hyprland.conf"
    local themedir="$HOME/.config/hypr/themes"
    local active=$(readlink "$HOME/.config/themes/active" 2>/dev/null)

    typeset -A descriptions=(
        rose-pine        "soft purple, calm"
        rose-pine-moon   "brighter Rosé Pine dark"
        gruvbox          "earthy yellow/orange, classic"
        kanagawa-wave    "Japanese woodblock blues"
        kanagawa-dragon  "ink-on-stone, very dark"
        everforest-dark  "sage forest, mossy greens"
        ayu-mirage       "warm cocoa, rust accents"
        iceberg-dark     "cold blue, stone temple"
        carbonfox        "matte black, IBM Carbon"
    )

    if [[ -z "$name" || "$name" == list || "$name" == help || "$name" == -h || "$name" == --help ]]; then
        print "available themes:"
        for f in "$themedir"/*.conf(N); do
            local n="${f:t:r}"
            local marker="  "
            [[ "$n" == "$active" ]] && marker="● "
            local desc="${descriptions[$n]:-}"
            if [[ -n "$desc" ]]; then
                printf "  %s%-18s %s\n" "$marker" "$n" "$desc"
            else
                printf "  %s%s\n" "$marker" "$n"
            fi
        done
        print ""
        print "usage: theme <name>"
        return 0
    fi

    if [[ ! -f "$themedir/$name.conf" ]]; then
        print -u2 "no such theme: $name"
        print -u2 "run 'theme list' to see options"
        return 1
    fi

    sed -i -E 's|^[[:space:]]*source[[:space:]]*=[[:space:]]*~/\.config/hypr/themes/[A-Za-z0-9_.-]+\.conf[[:space:]]*$|# &|' "$hyprconf"
    sed -i -E "s|^#[[:space:]]*(source[[:space:]]*=[[:space:]]*~/\.config/hypr/themes/$name\.conf)[[:space:]]*\$|\1|" "$hyprconf"
    "$HOME/.local/bin/theme-apply" "$name" >/dev/null 2>&1
    hyprctl reload >/dev/null 2>&1
    print "theme: $name"
}


# zoxide: smarter cd. `cd` is replaced by zoxide; `cdi` gives interactive pick.
# Must be initialized last so its prefix-cd and chpwd hooks wrap everything.
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"
