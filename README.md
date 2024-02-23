# Dotfiles

## Pattern
This repo is meant for dotfile storage inspired by [this](https://www.atlassian.com/git/tutorials/dotfiles) article. Using a bare git repo makes git the only requirement to setup a new machine or to sync config across devices.

### Device specific config
Use branches to store config differences for different devices. This way you can still sync changes trough the main branch and use the branch as a device specific "patch" to apply minor changes.

## Usage

### Backup brew
You can use brew bundle to backup your brew taps, casks and mac apps. Start by installing brew:
