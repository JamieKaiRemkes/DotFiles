# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Update automatically without asking
zstyle ':omz:update' mode auto      
zstyle ':omz:update' frequency 7

# Default plugins
plugins=(git node nvm docker doctl kubectl helm doctl vscode)

# Load omzsh
source $ZSH/oh-my-zsh.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='code'
fi

# Download Znap, if it's not there yet. 
[[ -r ~/.znap/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/.znap/znap

# Start Znap
source ~/.znap/znap/znap.zsh  

# Znap plugins
znap prompt sindresorhus/pure
znap prompt marlonrichert/zsh-autocomplete

# Add Visual Studio Code (code)
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# Set VS Code as default editor for kubectl
export KUBE_EDITOR='code --wait'

# Alias for using bare git as dotfiles storage
alias dot='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dst='dot status'
alias da='dot add'
alias daa='dot add -u'
alias drm='dot rm'
alias dc='dot commit'
alias dcm='dot commit -m'
alias dp='dot push'
alias dpr='dot pull --rebase'

# Aliasses for using zsh
alias ss='source .zshrc'

# Load env variables
[[ -r ~/.znap/znap/znap.zsh ]] &&
    source $HOME/.zshenv