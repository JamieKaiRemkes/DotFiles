# Aliases for using bare git as dotfiles storage (backed by ~/cli/dot)
# unalias dot 2>/dev/null
alias dst="dot status"
alias da="dot add -f"
alias daa="dot add -u"
alias drm="dot rm"
alias dc="dot commit"
alias dcm="dot commit -m"
alias dp="dot push"
alias dplr="dot pull --rebase"
alias dplra="dot pull --rebase --autostash"
alias de="dot edit"