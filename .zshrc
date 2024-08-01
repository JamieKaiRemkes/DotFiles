# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="jonathan"

# Update manualy without asking
# zstyle ':omz:update' mode auto      
# zstyle ':omz:update' frequency 7
DISABLE_AUTO_UPDATE=true 

# Default plugins
plugins=(1password argocd aws azure brew bun colorize deno docker docker-compose doctl dotenv encode64 flutter gcloud gh git golang helm kubectl microk8s nmap node npm nvm pip pipenv postgres python qrcode systemd terraform vscode)

# Load omzsh
source $ZSH/oh-my-zsh.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
  export KUBE_EDITOR='nano'
else
  export EDITOR='code --wait'
  export KUBE_EDITOR='code --wait'
fi

# Download Znap, if it's not there yet. 
[[ -r ~/.znap/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/.znap/znap

# Start Znap
source ~/.znap/znap/znap.zsh  

# Znap plugins
znap source marlonrichert/zsh-autocomplete

# Add Visual Studio Code (code)
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# Load aliases
[[ -d ~/.aliases ]] &&
    for f in $HOME/.aliases/*; do source $f; done

# Load aliases
[[ -d ~/.completions ]] &&
    for f in $HOME/.completions/*.zsh; do source $f; done

# Default env
export DEFAULT_NPM_REGISTRY='https://registry.npmjs.org/'

# Load env variables
[[ -r ~/.zshenv ]] &&
    source $HOME/.zshenv
