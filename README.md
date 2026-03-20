# Dotfiles

## Pattern
This repo is meant for dotfile storage inspired by [this](https://www.atlassian.com/git/tutorials/dotfiles) article. Using a bare git repo makes git the only requirement to setup a new machine or to sync config across devices.

### Device specific config
Use branches to store config differences for different devices. This way you can still sync changes trough the main branch and use the branch as a device specific "patch" to apply minor changes.

## Quick Install
On a fresh machine with `git` and `curl` available:
```sh
bash <(curl -fsSL https://raw.githubusercontent.com/JamieKaiRemkes/DotFiles/main/install.sh)
```

With options:
```sh
bash <(curl -fsSL https://raw.githubusercontent.com/JamieKaiRemkes/DotFiles/main/install.sh) --branch my-device --ssh-key ~/.ssh/my_key
```

The installer handles:
- **zsh** — installs & sets as default shell
- **Homebrew** — installs if missing
- **Oh My Zsh** — installs if missing
- **Dotfiles** — clones the bare repo to `~/.dotfiles` and checks out
- **Znap** — zsh plugin manager
- **asdf** — version manager (used for Java)
- **Brewfile** — installs all taps, formulae, casks & VS Code extensions

## Manual Setup
If you prefer to set up step by step:

### Install zsh & Oh My Zsh
```sh
sudo apt install zsh &&
chsh -s $(which zsh) &&
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Clone the repo
```sh
git clone --bare -c "core.sshCommand=ssh -i ~/.ssh/github" git@github.com:JamieKaiRemkes/DotFiles.git ~/.dotfiles
```

### Checkout
```sh
alias dot="git --git-dir=$HOME/.dotfiles --work-tree ~" &&
dot checkout main --force &&
source ~/.zshrc
```

## Usage

### The `dot` CLI
A CLI that wraps the bare git repo and adds convenience commands. Works from any directory.

```sh
dot <command> [args]
```

| Command | Description |
|---|---|
| `dot sync` | Pull (rebase + autostash) and push |
| `dot brew-sync` | Install remote Brewfile packages, dump local state, commit & push |
| `dot install` | Run the full dotfiles installer |
| `dot edit` | Open dotfiles in VS Code |
| `dot help` | Show usage information |
| `dot <git cmd>` | Any git command passed to the bare repo |

#### Examples
```sh
dot sync                          # pull + push
dot brew-sync                     # sync Homebrew packages across machines
dot status                        # see changed dotfiles
dot add -f ~/.config/new/file     # track a new file
dot commit -m "feat: add config"  # commit with conventional commit
dot log --oneline                 # view history
dot diff                          # see uncommitted changes
```

### Aliases
Shorthand aliases are available for common operations:

| Alias | Expands to |
|---|---|
| `dst` | `dot status` |
| `da` | `dot add -f` |
| `daa` | `dot add -u` |
| `dc` | `dot commit` |
| `dcm` | `dot commit -m` |
| `dp` | `dot push` |
| `dplr` | `dot pull --rebase` |
| `dplra` | `dot pull --rebase --autostash` |
| `drm` | `dot rm` |
| `de` | `dot edit` |

### Brew sync
Sync Homebrew packages across machines. This merges packages from remote with your local installs:

```sh
dot brew-sync
```

What it does:
1. **Pulls** latest dotfiles (picks up Brewfile changes from other machines)
2. **Installs** any packages from the remote Brewfile not yet installed locally
3. **Dumps** all currently installed packages back into the Brewfile
4. **Commits & pushes** if the Brewfile changed

### Tracking new files
Since the bare repo ignores untracked files by default, you need to force-add new files:

```sh
dot add -f ~/.config/some/new-file
dot commit -m "feat: track new config file"
dot push
```
