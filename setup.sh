#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Codeactive - Debian Dev Environment Setup
# =============================================================================
# Run as your user (with sudo access). Do NOT run as root directly.
#   chmod +x setup.sh && ./setup.sh
#
# This script expects the config/ directory next to it:
#   setup.sh
#   config/
#     cursor/settings.json
#     cursor/keybindings.json
#     cursor/extensions.txt
#   docker-compose.postgres.yml
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# CHANGE THESE TO MATCH THE PROJECT
# ---------------------------------------------------------------------------
PYTHON_VERSION="3.11.9"        # <-- CHANGE THIS to match Codeactive's version
GIT_NAME="Martin SICOT"
GIT_EMAIL="martin@sicotsoft.com"  # <-- CHANGE if they give you a company email

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

info "Installing essential build tools and libraries..."
sudo apt install -y \
    build-essential \
    curl \
    wget \
    git \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    libpq-dev \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    jq \
    htop \
    tree \
    fuse libfuse2  # needed for AppImage (Cursor)

# ---------------------------------------------------------------------------
# 2. Git config
# ---------------------------------------------------------------------------
info "Configuring git..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global push.autosetupremote true
git config --global init.defaultBranch main
git config --global core.editor "cursor --wait"

# ---------------------------------------------------------------------------
# 3. Zsh + Oh My Zsh
# ---------------------------------------------------------------------------
info "Installing zsh..."
sudo apt install -y zsh

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ "$SHELL" != "$(which zsh)" ]; then
    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi

# ---------------------------------------------------------------------------
# 4. Terminal: WezTerm + Nerd Font
# ---------------------------------------------------------------------------
info "Installing WezTerm terminal..."
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo apt update
sudo apt install -y wezterm || warn "WezTerm install failed - you can install manually later"

# Install JetBrains Mono Nerd Font (good rendering in WezTerm + Cursor terminal)
info "Installing JetBrains Mono Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
if [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    wget -q --show-progress -O /tmp/JetBrainsMono.tar.xz "$FONT_URL" || warn "Font download failed"
    if [ -f /tmp/JetBrainsMono.tar.xz ]; then
        tar -xf /tmp/JetBrainsMono.tar.xz -C "$FONT_DIR"
        fc-cache -fv "$FONT_DIR" > /dev/null 2>&1
        rm -f /tmp/JetBrainsMono.tar.xz
        info "JetBrains Mono Nerd Font installed"
    fi
else
    info "JetBrains Mono Nerd Font already installed, skipping..."
fi

# ---------------------------------------------------------------------------
# 5. pyenv + Python
# ---------------------------------------------------------------------------
if [ ! -d "$HOME/.pyenv" ]; then
    info "Installing pyenv..."
    curl https://pyenv.run | bash
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

info "Installing Python ${PYTHON_VERSION}..."
pyenv install -s "$PYTHON_VERSION"
pyenv global "$PYTHON_VERSION"

info "Installing pipenv + ipdb..."
pip install --upgrade pip
pip install pipenv ipdb

# ---------------------------------------------------------------------------
# 6. Docker
# ---------------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
    info "Installing Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    info "Docker already installed, skipping..."
fi

sudo usermod -aG docker "$USER"
info "Added $USER to docker group (log out/in for this to take effect)"

# ---------------------------------------------------------------------------
# 7. Cursor + config porting
# ---------------------------------------------------------------------------
info "Installing Cursor..."
CURSOR_URL="https://downloader.cursor.sh/linux/appImage/x64"
CURSOR_DIR="$HOME/.local/bin"
mkdir -p "$CURSOR_DIR"

if [ ! -f "$CURSOR_DIR/cursor.AppImage" ]; then
    wget -q --show-progress -O "$CURSOR_DIR/cursor.AppImage" "$CURSOR_URL" || warn "Cursor download failed - install manually from cursor.com"
    chmod +x "$CURSOR_DIR/cursor.AppImage"

    # Symlink so 'cursor' works from terminal
    ln -sf "$CURSOR_DIR/cursor.AppImage" "$CURSOR_DIR/cursor"

    # Desktop entry for app launcher
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/cursor.desktop" << DESKTOP
[Desktop Entry]
Name=Cursor
Comment=AI Code Editor
Exec=$HOME/.local/bin/cursor.AppImage --no-sandbox %F
Terminal=false
Type=Application
Icon=cursor
Categories=Development;IDE;
MimeType=text/plain;
DESKTOP
    info "Cursor installed at $CURSOR_DIR/cursor.AppImage"
else
    info "Cursor already installed, skipping..."
fi

# Port Cursor settings and keybindings from config/
CURSOR_CONFIG_DIR="$HOME/.config/Cursor/User"
mkdir -p "$CURSOR_CONFIG_DIR"

if [ -f "$SCRIPT_DIR/config/cursor/settings.json" ]; then
    cp "$SCRIPT_DIR/config/cursor/settings.json" "$CURSOR_CONFIG_DIR/settings.json"
    info "Cursor settings.json ported"
fi

if [ -f "$SCRIPT_DIR/config/cursor/keybindings.json" ]; then
    cp "$SCRIPT_DIR/config/cursor/keybindings.json" "$CURSOR_CONFIG_DIR/keybindings.json"
    info "Cursor keybindings.json ported"
fi

# Install extensions
if [ -f "$SCRIPT_DIR/config/cursor/extensions.txt" ]; then
    info "Installing Cursor extensions..."
    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        "$CURSOR_DIR/cursor.AppImage" --install-extension "$ext" --no-sandbox 2>/dev/null || warn "Failed to install extension: $ext"
    done < "$SCRIPT_DIR/config/cursor/extensions.txt"
fi

# ---------------------------------------------------------------------------
# 8. Chrome
# ---------------------------------------------------------------------------
if ! command -v google-chrome &> /dev/null; then
    info "Installing Google Chrome..."
    wget -q --show-progress -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo dpkg -i /tmp/chrome.deb || sudo apt install -f -y
    rm -f /tmp/chrome.deb
    info "Chrome installed"
else
    info "Chrome already installed, skipping..."
fi

# ---------------------------------------------------------------------------
# 9. Zen Browser
# ---------------------------------------------------------------------------
info "Installing Zen Browser..."
if [ ! -f "$CURSOR_DIR/zen" ]; then
    ZEN_URL=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest | jq -r '.assets[] | select(.name | test("zen.linux-x86_64.tar.xz$")) | .browser_download_url' 2>/dev/null)
    if [ -n "$ZEN_URL" ] && [ "$ZEN_URL" != "null" ]; then
        wget -q --show-progress -O /tmp/zen.tar.xz "$ZEN_URL"
        mkdir -p "$HOME/.local/share/zen"
        tar -xf /tmp/zen.tar.xz -C "$HOME/.local/share/zen" --strip-components=1
        ln -sf "$HOME/.local/share/zen/zen" "$CURSOR_DIR/zen"
        rm -f /tmp/zen.tar.xz

        # Desktop entry
        cat > "$HOME/.local/share/applications/zen.desktop" << ZENDESKTOP
[Desktop Entry]
Name=Zen Browser
Comment=Arc-like browser for Linux
Exec=$HOME/.local/share/zen/zen %u
Terminal=false
Type=Application
Icon=$HOME/.local/share/zen/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
ZENDESKTOP
        info "Zen Browser installed"
    else
        warn "Could not fetch Zen Browser release URL - install manually from zen-browser.app"
    fi
else
    info "Zen Browser already installed, skipping..."
fi

# ---------------------------------------------------------------------------
# 10. pgcli
# ---------------------------------------------------------------------------
info "Installing pgcli..."
pip install pgcli || warn "pgcli install failed - try: pip install pgcli later"

# ---------------------------------------------------------------------------
# 11. Claude Code CLI
# ---------------------------------------------------------------------------
info "Installing Claude Code CLI..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install -g @anthropic-ai/claude-code || warn "Claude Code CLI install failed - try: npm i -g @anthropic-ai/claude-code later"

# ---------------------------------------------------------------------------
# 12. Node.js (via nvm)
# ---------------------------------------------------------------------------
if [ ! -d "$HOME/.nvm" ]; then
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    info "Node.js LTS installed"
else
    info "nvm already installed, skipping..."
fi

# ---------------------------------------------------------------------------
# 13. Zsh config — porting your macOS workflow
# ---------------------------------------------------------------------------
info "Writing .zshrc..."

cat > "$HOME/.zshrc" << 'ZSHRC'
# ===========================================================================
# Martin's Zsh Config — Debian (ported from macOS)
# ===========================================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# --- Custom prompt (same as macOS) ---
autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats 'on %b '

RED=$'%{\e[1;31m%}'
GREEN=$'%{\e[1;32m%}'
YELLOW=$'%{\e[1;33m%}'
NC=$'%{\e[0m%}'

PROMPT="${RED}\$>${NC} "
RPROMPT="[${GREEN}\${vcs_info_msg_0_}${YELLOW}%~${NC}]"
function precmd () {
  vcs_info
  window_title="\033]0;${PWD#$HOME/}\007"
  echo -ne "$window_title"
}

# --- pyenv ---
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# --- nvm ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# --- Python env ---
export PYTHONBREAKPOINT=ipdb.set_trace
export PIPENV_VENV_IN_PROJECT=1

# --- PATH ---
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# --- Git aliases ---
alias gg="git grep -n "
alias gs="git switch"
alias gst="git status"
alias gd="git diff"
alias gl="git log --oneline -20"

# --- Docker aliases ---
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcr="docker compose restart"
alias dclogs="docker compose logs -f"

# --- Django aliases ---
alias pm="python manage.py"
alias pmr="python manage.py runserver"
alias pmm="python manage.py migrate"
alias pmk="python manage.py makemigrations"
alias pms="python manage.py shell"

# --- Postgres (local dev) ---
alias pgcli-dev="pgcli -h localhost -U codeactive -d codeactive"

# --- Cursor aliases ---
alias cursor="cursor --no-sandbox"
alias cursor-new="cursor --no-sandbox --new-window"
ZSHRC

info ".zshrc written with full config"

# ---------------------------------------------------------------------------
# 14. Create project workspace + copy docker-compose
# ---------------------------------------------------------------------------
mkdir -p "$HOME/dev"

if [ -f "$SCRIPT_DIR/docker-compose.postgres.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.postgres.yml" "$HOME/dev/docker-compose.postgres.yml"
    info "docker-compose.postgres.yml copied to ~/dev/"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "What got installed:"
echo "  - System build tools + libs"
echo "  - Git (configured)"
echo "  - Zsh + Oh My Zsh (with your macOS prompt)"
echo "  - WezTerm terminal + JetBrains Mono Nerd Font"
echo "  - pyenv + Python ${PYTHON_VERSION} + pipenv + ipdb"
echo "  - Docker + Docker Compose"
echo "  - Cursor (with your settings, keybindings, extensions)"
echo "  - Google Chrome"
echo "  - Zen Browser (Arc alternative)"
echo "  - pgcli (Postgres CLI)"
echo "  - Claude Code CLI"
echo "  - nvm + Node.js LTS"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for docker group + zsh)"
echo "  2. Clone the Codeactive repo into ~/dev/"
echo "  3. cd into the project and run: pipenv install"
echo "  4. Start Postgres: cd ~/dev && dc -f docker-compose.postgres.yml up -d"
echo "  5. Connect to DB: pgcli-dev"
echo "  6. Open Cursor: cursor ~/dev/codeactive"
echo ""
warn "Remember to change PYTHON_VERSION in this script if ${PYTHON_VERSION} is wrong!"
