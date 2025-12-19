# Default stubs
log_debug(){ :; }
log_info(){ :; }
log_warn(){ :; }
log_error(){ :; }

# Force non-interactive unless overridden
export MENU_NON_INTERACTIVE=1

# Disable real fzf unless test enables it
export MENU_NO_FZF=1

# Load menu system
source ./lib/menu/index.sh
