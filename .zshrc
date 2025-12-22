# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="jonathan"

# Update manualy without asking
# zstyle ':omz:update' mode auto      
# zstyle ':omz:update' frequency 7
DISABLE_AUTO_UPDATE=true 

# Default plugins
plugins=(1password argocd asdf aws azure brew colorize docker docker-compose doctl encode64 gcloud gh git golang helm kubectl microk8s nmap node npm nvm postgres python qrcode systemd terraform vscode)

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

# Add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# Add Visual Studio Code (code)
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# Load aliases
[[ -d ~/.aliases ]] &&
    for f in $HOME/.aliases/*.zsh; do source $f; done

# Load completions
[[ -d ~/.completions ]] &&
    for f in $HOME/.completions/*.zsh; do source $f; done

# Default env
export DEFAULT_NPM_REGISTRY='https://registry.npmjs.org/'

# Default env
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH=$JAVA_HOME/bin:$PATH

# Load env variables
[[ -r ~/.zshenv ]] &&
    source $HOME/.zshenv

. "$HOME/.local/share/../bin/env"

# Default env dynamic additions
export KUBECONFIG="${KUBECONFIG:+$KUBECONFIG:}$(find ./ -type f -name "*.kubeconfig" | tr '\n' ':' | sed 's/:$//')"

# Java env
. ~/.asdf/plugins/java/set-java-home.zsh
