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
			cp "$HOME/.cargo/bin/rtk" "$HOME/.local/bin/rtk"
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

pi_config_permission_system() {
	cat <<EOF | sed 's/\t/  /g' > $1
{
  "permission": {
    "*": "allow",
    "path": {
      "*": "allow",
      "*.env": "deny",
      "*.env*": "deny",
      "*.env.example": "allow",
      "~/.ssh/*": "deny",
      "~/.pi/agent/auth.json": "deny",
      "~/.pi/agent/models.json": "deny"
    },
    "bash": {
      "*": "ask",

      "cat *": "allow",
      "echo *": "allow",
      "find *": "allow",
      "git diff *": "allow",
      "grep *": "allow",
      "head *": "allow",
      "ls *": "allow",
      "read *": "allow",
      "tail *": "allow",
      "write *": "allow",
      "rtk cat *": "allow",
      "rtk echo *": "allow",
      "rtk find *": "allow",
      "rtk git diff *": "allow",
      "rtk grep *": "allow",
      "rtk head *": "allow",
      "rtk ls *": "allow",
      "rtk read *": "allow",
      "rtk tail *": "allow",
      "rtk write *": "allow",

      "chmod *": "deny",
      "chown *": "deny",
      "eval *": "deny",
      "exec *": "deny",
      "git branch *": "deny",
      "git checkout *": "deny",
      "git push *": "deny",
      "git rebase *": "deny",
      "git reset *": "deny",
      "rm -rf *": "deny",
      "sudo *": "deny",
      "write *": "allow",
      "rtk chmod *": "deny",
      "rtk chown *": "deny",
      "rtk eval *": "deny",
      "rtk exec *": "deny",
      "rtk git branch *": "deny",
      "rtk git checkout *": "deny",
      "rtk git push *": "deny",
      "rtk git rebase *": "deny",
      "rtk git reset *": "deny",
      "rtk rm -rf *": "deny",
      "rtk sudo *": "deny"
    },
    "external_directory": "ask"
  }
}
EOF
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
		pi install npm:pi-cache-optimizer
		# rtk-optimizer needs export RTK_DB_PATH in .bashrc to work properly without exporting it every time
		pi install npm:pi-rtk-optimizer
		echo -e "\nexport RTK_DB_PATH=\$HOME/.pi/agent/extensions/pi-rtk-optimizer/history.db" >> "$HOME/.bashrc"
		pi install npm:@alexanderfortin/pi-token-usage
		pi install npm:@benvargas/pi-claude-code-use
		# install permission system and configure it
		pi install npm:@gotgenes/pi-permission-system
		pi_config_permission_system ~/.pi/agent/extensions/pi-permission-system/config.json
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

to_lowercase() {
	echo "$1" | tr '[:upper:]' '[:lower:]'
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
	INSTALL_OH_MY_BASH=$(to_lowercase "${INSTALL_OH_MY_BASH:-y}")
	INSTALL_PI=$(to_lowercase "${INSTALL_PI:-y}")
	INSTALL_HERMES=$(to_lowercase "${INSTALL_HERMES:-n}")
	INSTALL_CLAUDE=$(to_lowercase "${INSTALL_CLAUDE:-n}")
	INSTALL_NPM=$(to_lowercase "${INSTALL_NPM:-y}")
	INSTALL_RUST=$(to_lowercase "${INSTALL_RUST:-n}")
	INSTALL_GO=$(to_lowercase "${INSTALL_GO:-n}")

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
