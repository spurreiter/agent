#!/usr/bin/env bash

set -euo pipefail
# set -x

cd $HOME

install_oh_my_bash() {
	local oh_my_bash_path="$HOME/.oh-my-bash"
	if [ $FORCE_INSTALL = "y" ]; then
		rm -rf "$oh_my_bash_path"
	fi
	if [ ! -d "$oh_my_bash_path" ]; then
		echo "Installing Oh My Bash (non-blocking)..."
		curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash
	else
		echo "Oh My Bash is already installed."
	fi
	local export_path_line='export PATH="$HOME/.local/share/npm/bin:$HOME/.local/share/go/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'
	if ! grep -q "$export_path_line" "$HOME/.bashrc"; then
		echo "$export_path_line" >> "$HOME/.bashrc"
	fi
}

install_go() {
	local go_version="1.26.5"
	local go_bin_path="$HOME/.local/share/bin/go"
	if [ $FORCE_INSTALL = "y" ]; then
		test -f "$go_bin_path" && rm "$go_bin_path"
	fi
	if [ ! -f "$go_bin_path" ]; then
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
	if [ $FORCE_INSTALL = "y" ]; then
		rm -rf "$HOME/.rustup"
		rm -rf "$HOME/.cargo"
	fi
	if [ ! -f "$HOME/.cargo/bin/rustc" ]; then
		echo "Installing Rust..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	else
		echo "Rust is already installed."
	fi
}

install_rtk() {
	# if [ $FORCE_INSTALL = "y" ]; then
	# 	rm "$HOME/.local/bin/rtk"
	# fi
	if [ ! -f "$HOME/.local/bin/rtk" ]; then
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
	else
		echo "RTK is already installed."
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
	if [ $FORCE_INSTALL = "y" ] || [ ! -f "$HOME/.local/share/npm/bin/prettier" ]; then
		echo "Installing npm packages..."
		npm install -g \
			prettier \
			@fission-ai/openspec \
			skills \
			sort-package-json \
			pnpm
	else
		echo "npm packages are already installed."
	fi
}

pi_config_permission_system() {
	local config_path="$(dirname "$1")"
	test ! -d "$config_path" && mkdir -p "$config_path"
	cat <<EOF | jq '.permission.bash |= . + (to_entries | map(select(.key | startswith("rtk ") | not) | {("rtk " + .key): .value}) | add // {})' > $1
{
  "permission": {
    "*": "allow",
    "path": {
      "*.env.example": "allow",
      "*.env": "deny",
      "*.env*": "deny",
      "*": "allow",
      "~/.claude/*": "deny",
      "~/.config/*": "deny",
      "~/.local/*": "deny",
      "~/.pi/*": "deny",
      "~/.ssh/*": "deny"
    },
    "bash": {
      "*": "ask",
      "awk *": "allow",
      "cat *": "allow",
      "echo *": "allow",
      "find *": "allow",
      "git diff *": "allow",
      "grep *": "allow",
      "head *": "allow",
      "jq *": "allow",
      "ls *": "allow",
      "read *": "allow",
      "rg *": "allow",
      "sed *": "allow",
      "tail *": "allow",
      "write *": "allow",
      "apt *": "deny",
      "brew *": "deny",
      "chmod *": "deny",
      "chown *": "deny",
      "curl *": "deny",
      "docker *": "deny",
      "eval *": "deny",
      "exec *": "deny",
      "git branch *": "deny",
      "git checkout *": "deny",
      "git push *": "deny",
      "git rebase *": "deny",
      "git reset *": "deny",
      "npm install *": "deny",
      "perl -i *": "deny",
      "pip install *": "deny",
      "pnpm add *": "deny",
      "pnpm install *": "deny",
      "rm -rf *": "deny",
      "sudo *": "deny",
      "wget *": "deny",
      "yarn add *": "deny"
    },
    "external_directory": "ask"
  }
}
EOF
}

pi_config_rtk_optimizer() {
	if ! grep -q "export RTK_DB_PATH=" "$HOME/.bashrc"; then
		echo -e "\nexport RTK_DB_PATH=\$HOME/.pi/agent/extensions/pi-rtk-optimizer/history.db" >> "$HOME/.bashrc"
	fi
}

install_pi_agent() {
	if [ $FORCE_INSTALL = "y" ] || [ ! -f "$HOME/.local/share/npm/bin/pi" ]; then
		npm install -g \
			@earendil-works/pi-coding-agent
		# install pi-agent packages
		pi install npm:pi-mcp-adapter
		pi install npm:pi-web-access
		pi install npm:pi-cache-optimizer
		# rtk-optimizer needs export RTK_DB_PATH in .bashrc to work properly without exporting it every time
		pi install npm:pi-rtk-optimizer
		pi_config_rtk_optimizer
		pi install npm:@alexanderfortin/pi-token-usage
		pi install npm:@benvargas/pi-claude-code-use
		# install permission system and configure it
		pi install npm:@gotgenes/pi-permission-system
		pi_config_permission_system ~/.pi/agent/extensions/pi-permission-system/config.json
	else
		echo "pi-agent is already installed."
	fi
}

install_hermes_agent() {
	if [ $FORCE_INSTALL = "y" ] || [ ! -f "$HOME/.local/bin/hermes" ]; then
		echo "Installing hermes-agent..."
		curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
	else
		echo "hermes-agent is already installed."
	fi
}

claude_config_permissions() {
	if [ ! -d "$HOME/.claude" ]; then
		mkdir -p "$HOME/.claude"
	fi
	if [ ! -f "$HOME/.claude/settings.json" ]; then
		# See https://code.claude.com/docs/en/settings#permission-rule-syntax
		cat <<EOF | sed 's/\t/  /g' > $HOME/.claude/settings.json
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "sandbox": {
    "enabled": false,
    "failIfUnavailable": false
  },
  "permissions": {
    "allow": [
      "Bash(awk *)",
      "Bash(cat *)",
      "Bash(echo *)",
      "Bash(find *)",
      "Bash(git diff *)",
      "Bash(grep *)",
      "Bash(head *)",
      "Bash(jq *)",
      "Bash(ls *)",
      "Bash(read *)",
      "Bash(rg *)",
      "Bash(sed *)",
      "Bash(tail *)",
      "Bash(write *)",
      "Read(./.env.example)",
      "Write(./logs/*)",
      "Write(./.output*)"
    ],
    "deny": [
      "Bash(apt *)",
      "Bash(brew *)",
      "Bash(chmod *)",
      "Bash(chown *)",
      "Bash(curl *)",
      "Bash(docker *)",
      "Bash(eval *)",
      "Bash(exec *)",
      "Bash(git branch *)",
      "Bash(git checkout *)",
      "Bash(git push *)",
      "Bash(git rebase *)",
      "Bash(git reset *)",
      "Bash(npm install *)",
      "Bash(perl -i *)",
      "Bash(pip install *)",
      "Bash(pnpm add *)",
      "Bash(pnpm install *)",
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Bash(wget *)",
      "Bash(yarn add *)",
      "Read(.env)",
      "Read(.env*)",
      "Read(~/.aws)",
      "Read(~/.claude)",
      "Read(~/.config)",
      "Read(~/.local)",
      "Read(~/.pi)",
      "Read(~/.ssh)",
      "Write(./.env*)",
      "Write(~/.pi)",
      "Write(~/.ssh)",
      "Write(~/.config)",
      "Write(/etc/*)",
      "Write(/usr/*)"
    ]
  }
}
EOF
	fi
}

claude_config_permissions

install_claude_agent() {
	if [ $FORCE_INSTALL = "y" ] || [ ! -f "$HOME/.local/share/npm/bin/claude" ]; then
		echo "Installing claude-agent..."
		curl -fsSL https://claude.ai/install.sh | bash
	else
		echo "claude-agent is already installed."
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
	read -r -p "Force installation (overwrite existing)? (y/N) " FORCE_INSTALL || true

	# Normalize answers to lowercase
	INSTALL_OH_MY_BASH=$(to_lowercase "${INSTALL_OH_MY_BASH:-y}")
	INSTALL_PI=$(to_lowercase "${INSTALL_PI:-y}")
	INSTALL_HERMES=$(to_lowercase "${INSTALL_HERMES:-n}")
	INSTALL_CLAUDE=$(to_lowercase "${INSTALL_CLAUDE:-n}")
	INSTALL_NPM=$(to_lowercase "${INSTALL_NPM:-y}")
	INSTALL_RUST=$(to_lowercase "${INSTALL_RUST:-n}")
	INSTALL_GO=$(to_lowercase "${INSTALL_GO:-n}")
	FORCE_INSTALL=$(to_lowercase "${FORCE_INSTALL:-n}")

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
