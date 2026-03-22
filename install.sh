#!/usr/bin/env bash
# Dotfiles installer — bootstraps a new machine from the bare git repo.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/JamieKaiRemkes/DotFiles/main/install.sh | bash
#   — or —
#   bash install.sh [--branch <branch>] [--ssh-key <path>]
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────
DOTFILES_REPO="git@github.com:JamieKaiRemkes/DotFiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BRANCH="main"
SSH_KEY="$HOME/.ssh/github"

# ── Parse arguments ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch)  BRANCH="$2";  shift 2 ;;
        --ssh-key) SSH_KEY="$2"; shift 2 ;;
        *)         echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────
info()  { printf '\033[1;34m→ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m✗ %s\033[0m\n' "$*"; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

OS="$(uname -s)"

# ── 1. Core dependencies (git, curl) ─────────────────────
info "Checking core dependencies…"

if ! command_exists git; then
    if [[ "$OS" == "Darwin" ]]; then
        info "Installing Xcode Command Line Tools (includes git)…"
        xcode-select --install 2>/dev/null || true
        until command_exists git; do sleep 5; done
    else
        info "Installing git…"
        sudo apt-get update -qq && sudo apt-get install -yqq git curl
    fi
fi

if ! command_exists curl; then
    if [[ "$OS" == "Linux" ]]; then
        sudo apt-get update -qq && sudo apt-get install -yqq curl
    fi
fi

ok "git $(git --version | awk '{print $3}') & curl ready"

# ── 2. Zsh ────────────────────────────────────────────────
info "Checking zsh…"

if ! command_exists zsh; then
    if [[ "$OS" == "Darwin" ]]; then
        fail "zsh should be pre-installed on macOS"
    else
        info "Installing zsh…"
        sudo apt-get update -qq && sudo apt-get install -yqq zsh
    fi
fi

# Set zsh as default shell if it isn't already
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    info "Setting zsh as default shell…"
    sudo chsh -s "$(which zsh)" "$(whoami)"
fi

ok "zsh $(zsh --version | awk '{print $2}') ready"

# ── 3. Homebrew ───────────────────────────────────────────
info "Checking Homebrew…"

if ! command_exists brew; then
    info "Installing Homebrew…"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to current PATH
    if [[ "$OS" == "Darwin" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

ok "Homebrew $(brew --version | head -1 | awk '{print $2}') ready"

# ── 4. Oh My Zsh ─────────────────────────────────────────
info "Checking Oh My Zsh…"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh…"
    RUNZSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ok "Oh My Zsh ready"

# ── 5. Clone dotfiles bare repo ──────────────────────────
info "Checking dotfiles repo…"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    info "Cloning dotfiles bare repo…"
    if [[ -f "$SSH_KEY" ]]; then
        git clone --bare -c "core.sshCommand=ssh -i $SSH_KEY" "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
        warn "SSH key $SSH_KEY not found — cloning with default SSH config"
        git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
else
    ok "Dotfiles repo already exists at $DOTFILES_DIR"
fi

# Define the dot alias for this session
dot() { git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }

# Hide untracked files (essential for bare-repo-as-dotfiles pattern)
dot config status.showUntrackedFiles no

# ── 6. Checkout dotfiles ─────────────────────────────────
info "Checking out $BRANCH branch…"

dot checkout "$BRANCH" --force
ok "Dotfiles checked out"

# ── 7. Znap (zsh plugin manager) ─────────────────────────
info "Checking Znap…"

if [[ ! -d "$HOME/.znap/znap" ]]; then
    info "Installing Znap…"
    git clone --depth 1 https://github.com/marlonrichert/zsh-snap.git "$HOME/.znap/znap"
fi

ok "Znap ready"

# ── 8. asdf version manager ──────────────────────────────
info "Checking asdf…"

if [[ ! -d "$HOME/.asdf" ]]; then
    info "Installing asdf…"
    git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.14.1
fi

ok "asdf ready"

# ── 9. Brew bundle (install all packages) ────────────────
if [[ -f "$HOME/Brewfile" ]]; then
    info "Installing Homebrew packages from Brewfile…"
    brew bundle --file="$HOME/Brewfile" --no-lock || warn "Some Brewfile entries failed (non-fatal)"
    ok "Brewfile packages installed"
else
    warn "No Brewfile found — skipping brew bundle"
fi

# ── 10. Direnv hook (already in .zshrc) ──────────────────
if command_exists direnv; then
    ok "direnv ready"
fi

# ── Done ──────────────────────────────────────────────────
echo ""
ok "Installation complete!"
info "Next steps:"
echo "  1. Restart your shell or run: exec zsh"
echo "  2. If using a device-specific branch, run: dot checkout <branch>"
echo "  3. Add your SSH keys to ~/.ssh/ if not already present"
echo ""
