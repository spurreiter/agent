#!/usr/bin/env bash

set -euo pipefail
# set -x

cd $HOME

install_oh_my_bash() {
	if [ ! -d "$HOME/.oh-my-bash" ]; then
		echo "Installing Oh My Bash (non-blocking)..."
		curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash
  	else
    	echo "Oh My Bash is already installed."
  	fi
}

install_go() {
	local go_version="1.26.5"
	if [ ! -f "$HOME/.local/bin/go" ]; then
		echo "Installing Go..."
		if [ $(uname -m) = "aarch64" ]; then
			curl -fsSL https://go.dev/dl/go${go_version}.linux-arm64.tar.gz | tar -C "$HOME/.local/share" -xz
		else
			curl -fsSL https://go.dev/dl/go${go_version}.linux-amd64.tar.gz | tar -C "$HOME/.local/share" -xz
		fi
	else
		echo "Go is already installed."
	fi
}

install_rust() {
	if [ ! -f "$HOME/.cargo/bin/rustc" ]; then
		echo "Installing Rust..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	else
		echo "Rust is already installed."
	fi
}

install_rtk() {
	if [ -f "$HOME/.local/bin/rtk" ]; then
		echo "RTK is already installed."
	else
		if [ $(uname -m) = "aarch64" ]; then
			# See https://github.com/rtk-ai/rtk/pull/2831
			echo "Installing RTK for aarch64..."
			install_rust
			cargo install --git https://github.com/rtk-ai/rtk
		else
			echo "Installing RTK for x86_64..."
			curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
		fi
	fi
	cd "$HOME"
	if [ "$INSTALL_PI" = "y" ]; then
		rtk init --agent pi
	fi
	if [ "$INSTALL_HERMES" = "y" ]; then
		rtk init --agent hermes
	fi
	if [ "$INSTALL_CLAUDE" = "y" ]; then
		rtk init --agent claude
	fi
}

install_npm_packages() {
	if [ -f "$HOME/.local/share/npm/bin/prettier" ]; then
		echo "npm packages are already installed."
	else
		echo "Installing npm packages..."
		npm install -g \
			prettier \
			@fission-ai/openspec \
			skills \
			sort-package-json \
			pnpm
	fi
}

install_pi_agent() {
	if [ -f "$HOME/.local/share/npm/bin/pi" ]; then
		echo "pi-agent is already installed."
	else		
		npm install -g \
			@earendil-works/pi-coding-agent
		# install pi-agent packages
		pi install npm:pi-mcp-adapter
		pi install npm:pi-web-access
		pi install npm:@alexanderfortin/pi-token-usage
		pi install npm:pi-rtk-optimizer
		pi install npm:pi-cache-optimizer
		#pi install npm:@gotgenes/pi-permission-system
	fi
}

install_hermes_agent() {
	if [ -f "$HOME/.local/bin/hermes" ]; then
		echo "hermes-agent is already installed."
	else		
		curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
	fi
}

install_claude_agent() {
	if [ -f "$HOME/.local/share/npm/bin/claude" ]; then
		echo "claude-agent is already installed."
	else
		curl -fsSL https://claude.ai/install.sh | bash
	fi
}

ask_install_choice() {
	echo "Select which components you want to install. Answer y or n."
	read -r -p "Install Oh My Bash? (Y/n) " INSTALL_OH_MY_BASH || true
	read -r -p "Install pi-agent? (Y/n) " INSTALL_PI || true
	read -r -p "Install hermes-agent? (y/N) " INSTALL_HERMES || true
	read -r -p "Install claude-agent? (y/N) " INSTALL_CLAUDE || true
	read -r -p "Install common npm packages? (Y/n) " INSTALL_NPM || true
	read -r -p "Install rust? (y/N) " INSTALL_RUST || true
	read -r -p "Install go? (y/N) " INSTALL_GO || true

	# Normalize answers to lowercase
	INSTALL_OH_MY_BASH=$(echo "${INSTALL_OH_MY_BASH:-y}" | tr '[:upper:]' '[:lower:]')
	INSTALL_PI=$(echo "${INSTALL_PI:-y}" | tr '[:upper:]' '[:lower:]')
	INSTALL_HERMES=$(echo "${INSTALL_HERMES:-n}" | tr '[:upper:]' '[:lower:]')
	INSTALL_CLAUDE=$(echo "${INSTALL_CLAUDE:-n}" | tr '[:upper:]' '[:lower:]')
	INSTALL_NPM=$(echo "${INSTALL_NPM:-y}" | tr '[:upper:]' '[:lower:]')
	INSTALL_RUST=$(echo "${INSTALL_RUST:-n}" | tr '[:upper:]' '[:lower:]')
	INSTALL_GO=$(echo "${INSTALL_GO:-n}" | tr '[:upper:]' '[:lower:]')

	if [ "$INSTALL_OH_MY_BASH" = "y" ]; then
		install_oh_my_bash
	else
		echo "Skipping Oh My Bash."
	fi

	if [ "$INSTALL_PI" = "y" ]; then
		install_pi_agent
	else
		echo "Skipping pi-agent."
	fi

	if [ "$INSTALL_HERMES" = "y" ]; then
		install_hermes_agent
	else
		echo "Skipping hermes-agent."
	fi

	if [ "$INSTALL_CLAUDE" = "y" ]; then
		install_claude_agent
	else
		echo "Skipping claude-agent."
	fi

	if [ "$INSTALL_NPM" = "y" ]; then
		install_npm_packages
	else
		echo "Skipping npm package installation."
	fi

	if [ "$INSTALL_RUST" = "y" ]; then
		install_rust
	else
		echo "Skipping Rust installation."
	fi

	if [ "$INSTALL_GO" = "y" ]; then
		install_go
	else
		echo "Skipping Go installation."
	fi

	install_rtk
}

setup_complete() {
	echo "Setup complete. Please restart your terminal or run 'bash' to apply changes."
}

ask_install_choice
setup_complete
