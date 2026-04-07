# Completion for the dot CLI (~cli/dot)
_dot() {
    local -a dot_commands=(
        'sync:Pull (rebase + autostash) and push'
        'install:Run the dotfiles installer'
        'brew-sync:Merge remote Brewfile, install, dump & push'
        'edit:Open dotfiles in $EDITOR'
        'help:Show usage information'
    )

    local -a git_commands=(
        'status:Show working tree status'
        'add:Add file contents to the index'
        'commit:Record changes to the repository'
        'push:Update remote refs'
        'pull:Fetch and merge from remote'
        'log:Show commit logs'
        'diff:Show changes between commits'
        'checkout:Switch branches or restore files'
        'branch:List, create, or delete branches'
        'rm:Remove files from the working tree'
        'stash:Stash changes in a dirty working directory'
    )

    # Complete subcommands at position 1
    if (( CURRENT == 2 )); then
        zstyle ':completion:*:*:dot:*' group-name ''
        _describe -t dot 'dot command' dot_commands
        _describe -t git 'git command' git_commands
        return
    fi

    # For everything after the subcommand, delegate to git completion
    case "${words[2]}" in
        sync|install|brew-sync|edit|help) ;;
        *)
            # Shift words so git completion sees "git <subcmd> ..."
            words=("git" "${words[2,-1]}")
            (( CURRENT-- ))
            _git
            ;;
    esac
}

compdef _dot dot
