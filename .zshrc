#------------------------------------------------------------------------------
# ZSH CONFIGURATION
#------------------------------------------------------------------------------

# Shell options
setopt auto_cd          # Automatically cd to a directory if a command is its name
setopt share_history    # Share history between all concurrent shell sessions
setopt hist_ignore_dups # Do not record an event that was just recorded again

# History settings
HISTFILE=~/.zsh_history # Path to the history file
HISTSIZE=20000          # Maximum number of events stored in internal history
SAVEHIST=20000          # Maximum number of events saved to HISTFILE


# Define colors for use in custom scripts
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

#------------------------------------------------------------------------------
# KEY BINDINGS
#------------------------------------------------------------------------------
bindkey -e # Use Emacs keybindings

# Navigation & Editing
bindkey '^[[H'  beginning-of-line    # Home
bindkey '^[[F'  end-of-line          # End
bindkey '^[[3~' delete-char          # Delete
bindkey '^[[5~' up-line-or-history   # PageUp
bindkey '^[[6~' down-line-or-history # PageDown
bindkey '^[[A' up-line-or-search     # UpArrow
bindkey '^[[B' down-line-or-search   # DownArrow
bindkey '^[[C' forward-char          # RightArrow
bindkey '^[[D' backward-char         # LeftArrow

#------------------------------------------------------------------------------
# ALIASES, FUNCTIONS, AND ENVIRONMENT
#------------------------------------------------------------------------------

# Environment Variables
export EDITOR=nvim
# Use correct TERM variable for SSH sessions from Kitty
[[ "$TERM" == "xterm-kitty" ]] && alias ssh="TERM=xterm-256color ssh"

# General Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias zshrc="nvim ~/.zshrc"
alias c='clear'
alias ..='cd ..'
alias ll='ls -lha'
alias la='ls -A'

# --- Distro-Aware Package Management Aliases ---
# Detects the OS and sets aliases accordingly.
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
        arch|artix|endeavouros|manjaro)
            __zsh_distro_id="arch"
            alias update="sudo pacman -Syu"
            alias install="sudo pacman -S"
            alias remove="sudo pacman -Rs"
            alias search="pacman -Ss"
            ;;
        fedora|nobara)
            __zsh_distro_id="fedora"
            alias update="sudo dnf upgrade --refresh"
            alias install="sudo dnf install"
            alias remove="sudo dnf remove"
            alias search="dnf search"
            ;;
        *)
            __zsh_distro_id="unknown"
            ;;
    esac
fi

# take: Create a directory and cd into it
take() {
    mkdir -p "$1" && cd "$1"
}

#------------------------------------------------------------------------------
# PROMPT
#------------------------------------------------------------------------------
# Example: ~/Projects/my-project %
PROMPT='%F{blue}%~%f %# '

#------------------------------------------------------------------------------
# COMPLETION SYSTEM
#------------------------------------------------------------------------------
# Load Zsh's completion system, preventing alias expansion and forcing zsh-style autoloading.
autoload -Uz compinit
compinit

# --- Improved Completion Styling ---
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # Use ls colors for file completions
zstyle ':completion:*:*:*:*:*' 'group-name'             # Group completions by type
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # Case-insensitive completion

#------------------------------------------------------------------------------
# SUGGESTED ENHANCEMENTS (PLUGINS)
#------------------------------------------------------------------------------
# For a much better shell experience, install these plugins via your package manager
# (e.g., `sudo dnf install zsh-autosuggestions zsh-syntax-highlighting`)
# then uncomment the lines below.

# Zsh Autosuggestions (suggests commands as you type)
if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Zsh Syntax Highlighting (highlights commands and syntax in real time)
if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Safer 'rm' command using trash-cli (install with 'pip install trash-cli')
# alias rm='trash'

#------------------------------------------------------------------------------
# CUSTOM FUNCTIONS
#------------------------------------------------------------------------------

# --- Distro-Aware FZF Package Search ---
# Helper function for Arch Linux
_fzf_arch() {
    if ! command -v pacman &>/dev/null; then
        print -r -- "${RED}Error: pacman not found.${NC}" && return 1
    fi
    pacman -Qq | fzf --preview="pacman -Qi {1}" --preview-window="right:60%" --height=40% --layout=reverse --border
}

# Helper function for Fedora
_fzf_fedora() {
    if ! command -v dnf &>/dev/null; then
        print -r -- "${RED}Error: dnf not found.${NC}" && return 1
    fi
    rpm -qa --qf '%{NAME}\n' | fzf --preview="dnf info {1}" --preview-window="right:60%" --height=40% --layout=reverse --border
}

# fzf_pkgs: Interactively search installed packages using fzf.
# Automatically uses the correct package manager for your system.
fzf_pkgs() {
    if ! command -v fzf &>/dev/null; then
        print -r -- "${RED}Error: fzf is not installed.${NC}" && return 1
    fi

    case "$__zsh_distro_id" in
        arch)   _fzf_arch ;;
        fedora) _fzf_fedora ;;
        *)      print -r -- "${RED}Error: Unsupported distribution for fzf_pkgs.${NC}" && return 1 ;;
    esac
}

# obsidian_sync: Synchronize Obsidian vault with a remote rclone destination.
# Requires: rclone, zip, unzip
obsidian_sync() {
    local direction="$1"
    local -r vault_name="FoxVault"
    local -r local_archive_base_dir="$HOME/ProtonDrive/Archives/Obsidian"
    local -r remote_rclone_name="ProtonDrive"
    local -r remote_archive_path_on_drive="Archives/Obsidian"
    local -r local_vault_path="${local_archive_base_dir}/${vault_name}"
    local -r remote_base_rclone_path="${remote_rclone_name}:${remote_archive_path_on_drive}"

    # Define colors properly for zsh
    local -r RED=$'\033[0;31m'
    local -r GREEN=$'\033[0;32m'
    local -r YELLOW=$'\033[0;33m'
    local -r BLUE=$'\033[0;34m'
    local -r NC=$'\033[0m'  # No Color

    _obsidian_sync_check_prerequisites() {
        for tool in rclone zip unzip; do
            if ! command -v "$tool" &>/dev/null; then
                print -r -- "${RED}Error: Required tool '${tool}' is not installed.${NC}" && return 1
            fi
        done
        if ! rclone listremotes | grep -q "^${remote_rclone_name}:"; then
            print -r -- "${RED}Error: rclone remote '${remote_rclone_name}:' is not configured.${NC}" && return 1
        fi
        return 0
    }

    if ! _obsidian_sync_check_prerequisites; then return 1; fi

    if [[ "$direction" == "pull" ]]; then
        print -r -- "${BLUE}Pulling '${vault_name}' from '${remote_rclone_name}'...${NC}"
        local latest_backup_filename
        latest_backup_filename=$(rclone lsf "${remote_base_rclone_path}" --include "${vault_name}_*.zip" 2>/dev/null | sort -r | head -n 1)

        if [[ -z "$latest_backup_filename" ]]; then
            print -r -- "${RED}Error: No backups found in '${remote_base_rclone_path}'.${NC}" && return 1
        fi
        
        local -r remote_zip_to_download="${remote_base_rclone_path}/${latest_backup_filename}"
        local -r local_downloaded_zip_path="${local_archive_base_dir}/${latest_backup_filename}"

        print -r -- "-> Latest backup: ${YELLOW}${latest_backup_filename}${NC}"
        if ! mkdir -p "$local_archive_base_dir"; then print -r -- "${RED}Error: Could not create '${local_archive_base_dir}'.${NC}" && return 1; fi

        print -r -- "-> Downloading..."
        if ! rclone copy "$remote_zip_to_download" "$local_archive_base_dir/" --progress; then
            print -r -- "${RED}❌ Download failed.${NC}" && return 1
        fi

        local backup_dir_path=""
        if [[ -d "$local_vault_path" ]]; then
            backup_dir_path="${local_vault_path}_backup_$(date +%Y%m%d_%H%M%S)"
            print -r -- "-> Backing up existing vault to ${YELLOW}${backup_dir_path}${NC}"
            if ! mv "$local_vault_path" "$backup_dir_path"; then
                 print -r -- "${RED}❌ Failed to backup existing vault. Aborting.${NC}" && return 1
            fi
        fi

        print -r -- "-> Extracting archive..."
        if ! unzip -o "$local_downloaded_zip_path" -d "$(dirname "$local_vault_path")"; then
            print -r -- "${RED}❌ Failed to extract archive.${NC}"
            if [[ -n "$backup_dir_path" && -d "$backup_dir_path" ]]; then
                print -r -- "-> Attempting to restore from backup..."
                rm -rf "$local_vault_path"
                if mv "$backup_dir_path" "$local_vault_path"; then
                    print -r -- "${GREEN}✅ Successfully restored from backup.${NC}"
                else
                    print -r -- "${RED}❌ Failed to restore from backup. Manual intervention required.${NC}"
                fi
            fi
            return 1
        fi
        print -r -- "${GREEN}✅ '${vault_name}' successfully pulled.${NC}"

    elif [[ "$direction" == "push" ]]; then
        local -r timestamp=$(date "+%Y%m%d_%H%M%S")
        local -r zip_filename="${vault_name}_${timestamp}.zip"
        local -r local_zip_to_create_path="${local_archive_base_dir}/${zip_filename}"

        print -r -- "${BLUE}Pushing '${local_vault_path}' to '${remote_rclone_name}'...${NC}"

        if [[ ! -d "$local_vault_path" ]]; then
            print -r -- "${RED}Error: Local vault '${local_vault_path}' does not exist.${NC}" && return 1
        fi

        print -r -- "-> Creating zip archive..."
        # Create zip with relative paths by cd'ing into the parent directory first.
        if ! (cd "$(dirname "$local_vault_path")" && zip -rq "$local_zip_to_create_path" "$vault_name"); then
            print -r -- "${RED}❌ Failed to create zip file.${NC}" && rm -f "$local_zip_to_create_path" && return 1
        fi
        
        if [[ ! -f "$local_zip_to_create_path" ]]; then print -r -- "${RED}❌ Zip file not found after creation.${NC}" && return 1; fi

        print -r -- "-> Uploading ${YELLOW}${zip_filename}${NC}..."
        rclone mkdir "${remote_base_rclone_path}" 2>/dev/null
        if ! rclone copy "$local_zip_to_create_path" "${remote_base_rclone_path}/" --progress; then
            print -r -- "${RED}❌ Upload failed.${NC}" && return 1
        fi

        print -r -- "${GREEN}✅ '${vault_name}' successfully pushed.${NC}"

    else
        print -r -- "Usage: obsidian_sync [pull|push]"
    fi
    return 0
}

