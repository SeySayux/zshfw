# Example of a zshrc file for zshfw.

# First of all, set whether we are running in a system or user zsh
# environment.

#ZSHFW_SYSTEM=1

# Check if a zshfw is already loaded.

if [[ $ZSHFW_SYSTEM ]]; then
    export ZSHFW_SYSTEM_DIR=/etc/zsh
    source $ZSHFW_SYSTEM_DIR/zshfw
fi

if [[ ! $ZSHFW_SYSTEM && ! $ZSHFW_LOADED ]]; then
    export ZSHFW_USER_DIR=$HOME/.zsh
    source $ZSHFW_USER_DIR/zshfw
fi

# Setup your theme here.
loadtheme default

# Setup your plugins here.
loadplugins bashlike history zshlocal
