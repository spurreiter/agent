#!/usr/bin/env bash

set -euo pipefail
# set -x

cd "$HOME"

# Define default permission rules for Pi and Claude agents. These rules are used to configure the agents' access to files and commands.
path_allow=(
	'*.env.example'
	'/tmp/*'
	'/home/node/ws/*'
	'~/.local/share/npm/lib/node_modules/@earendil-works/pi-coding-agent/README.md'
	'~/.local/share/npm/lib/node_modules/@earendil-works/pi-coding-agent/docs/*'
)
path_deny=(
	'*.env'
	'*.env*'
	'~/.claude/*'
	'~/.config/*'
	'~/.local/*'
	'~/.pi/agent/*.json'
	'~/.ssh/*'
	'/etc/*'
	'/usr/*'
)
bash_allow=(
	'awk'
	'cat'
	'cd'
	'echo'
	'find'
	'git diff'
	'git log'
	'git status'
	'go'
	'gofmt'
	'grep'
	'head'
	'jq'
	'ls'
	'mkdir'
	'node'
	'npm'
	'openspec'
	'pwd'
	'read'
	'rg'
	'sed'
	'sort'
	'stat'
	'tail'
	'timeout'
	'tr'
	'tree'
	'tsc'
	'wc'
	'write'
)
bash_deny=(
	'apt'
	'brew'
	'chmod'
	'chown'
	'curl'
	'docker'
	'eval'
	'exec'
	'git branch'
	'git checkout'
	'git push'
	'git rebase'
	'git reset'
	'npm install'
	'perl -i'
	'pip install'
	'pnpm add'
	'pnpm install'
	'rm -rf'
	'rmdir'
	'sudo'
	'wget'
	'yarn add'
)

pi_bin="$HOME/.local/share/npm/bin/pi"
claude_bin="$HOME/.local/bin/claude"
hermes_bin="$HOME/.local/bin/hermes"

is_yes() {
	[[ "$1" == "y" ]]
}

to_json(){
	local array=("$@")	
	printf '%s\n' "${array[@]}" | jq -R -s -c 'split("\n")[:-1]'
}

create_directory() {
	local dir="$1"
	if [[ ! -d "$dir" ]]; then
		mkdir -p "$dir"
	fi
}

append_to_bashrc_once() {
	local line="$1"
	local bashrc="$HOME/.bashrc"

	touch "$bashrc"
	grep -Fqx "$line" "$bashrc" || printf '%s\n' "$line" >> "$bashrc"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || {
		printf 'Required command not found: %s\n' "$1" >&2
		return 1
	}
}

install_oh_my_bash() {
	local oh_my_bash_path="$HOME/.oh-my-bash"
	if is_yes "$FORCE_INSTALL"; then
		rm -rf "$oh_my_bash_path"
	fi
	if [[ ! -d "$oh_my_bash_path" ]]; then
		echo "Installing Oh My Bash..."
		require_command curl
		curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash
	else
		echo "Oh My Bash is already installed."
	fi

	append_to_bashrc_once 'export PATH="$HOME/.local/share/npm/bin:$HOME/.local/share/go/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'
}

install_go() {
	local go_version="1.26.5"
	local go_root="$HOME/.local/share/go"
	local go_bin_path="$go_root/bin/go"
	local architecture

	case "$(uname -m)" in
		x86_64) architecture="amd64" ;;
		aarch64|arm64) architecture="arm64" ;;
		*)
			printf 'Unsupported Go architecture: %s\n' "$(uname -m)" >&2
			return 1
			;;
	esac

	if is_yes "$FORCE_INSTALL"; then
		rm -rf "$go_root"
	fi
	if [[ -x "$go_bin_path" ]]; then
		echo "Go is already installed."
		return
	fi

	echo "Installing Go ${go_version}..."
	require_command curl
	require_command tar
	mkdir -p "$HOME/.local/share"
	curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
		"https://go.dev/dl/go${go_version}.linux-${architecture}.tar.gz" |
		tar -xz -C "$HOME/.local/share"
	[[ -x "$go_bin_path" ]] || {
		echo "Go installation did not create $go_bin_path" >&2
		return 1
	}
}

install_rust() {
	if is_yes "$FORCE_INSTALL"; then
		rm -rf "$HOME/.rustup" "$HOME/.cargo"
	fi
	if [[ ! -x "$HOME/.cargo/bin/rustc" ]]; then
		echo "Installing Rust..."
		require_command curl
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	else
		echo "Rust is already installed."
	fi
}

install_rtk() {
	local rtk_bin="$HOME/.local/bin/rtk"

	if is_yes "$FORCE_INSTALL"; then
		rm -f "$rtk_bin"
	fi
	if [[ ! -x "$rtk_bin" ]]; then
		curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
	fi
	[[ -x "$rtk_bin" ]] || {
		echo "RTK installation did not create $rtk_bin" >&2
		return 1
	}

	if [[ -x "$pi_bin" ]]; then
		"$rtk_bin" init --agent pi
	fi
	if [[ -x "$hermes_bin" ]]; then
		"$rtk_bin" init --agent hermes
	fi
	if [[ -x "$claude_bin" ]]; then
		"$rtk_bin" init --agent claude
	fi
}

install_npm_packages() {
	if is_yes "$FORCE_INSTALL" || [[ ! -x "$HOME/.local/share/npm/bin/prettier" ]]; then
		echo "Installing npm packages..."
		require_command npm
		npm install -g \
			@colbymchenry/codegraph \
			@fission-ai/openspec \
			pnpm \
			prettier \
			skills \
			sort-package-json
		echo "To add optional skills, run:"
		echo "  npx skills add -g https://github.com/mattpocock/skills"
		echo "  npx skills add -g https://github.com/fission-ai/openspec"
	else
		echo "npm packages are already installed."
	fi
}

pi_config_permission_system() {
	if [[ ! -x "$pi_bin" ]]; then
		echo "Skipping Pi permission configuration because Pi is not installed."
		return
	fi

	local config_json_path="$HOME/.pi/agent/extensions/pi-permission-system/config.json"

	if [[ -f "$config_json_path" ]] && ! is_yes "$FORCE_INSTALL"; then
		echo "Pi permission configuration already exists; preserving it (use --force to replace it)."
		return
	fi
	create_directory "$(dirname "$config_json_path")"
	require_command jq

	local path_allow_json=$(to_json "${path_allow[@]}")
	local path_deny_json=$(to_json "${path_deny[@]}")
	local bash_allow_json=$(to_json "${bash_allow[@]}")
	local bash_deny_json=$(to_json "${bash_deny[@]}")

	# Merge permission entries: keep existing, set default ask, and add allowed bash commands
	if ! jq \
		--argjson path_allow "$path_allow_json" \
		--argjson path_deny "$path_deny_json" \
		--argjson bash_allow "$bash_allow_json" \
		--argjson bash_deny "$bash_deny_json" '
		.permission |= (. // {})
		| .permission.path |= . + (reduce $path_allow[] as $path ({}; . + {("\($path)"): "allow"}) )
		| .permission.path |= . + (reduce $path_deny[] as $path ({}; . + {("\($path)"): "deny"}) )
		| .permission.bash |= . + (reduce $bash_allow[] as $cmd ({}; . + {("\($cmd) *"): "allow"}) )
		| .permission.bash |= . + (reduce $bash_deny[] as $cmd ({}; . + {("\($cmd) *"): "deny"}) )
		| .permission.bash |= . + (to_entries | map(select(.key | startswith("rtk ") | not) | {("rtk " + .key): .value}) | add // {})
		' > "$config_json_path" <<-'EOF'
		{
			"permission": {
				"*": "allow",
				"path": {},
				"bash": {
					"*": "ask"
				},
				"external_directory": "ask"
			}
		}
		EOF
	then
		echo "Failed to write Pi permission configuration." >&2
		return 1
	fi
}

pi_config_rtk_optimizer() {
	append_to_bashrc_once 'export RTK_DB_PATH="$HOME/.pi/agent/extensions/pi-rtk-optimizer/history.db"'
}

install_pi_agent() {
	if is_yes "$FORCE_INSTALL" || [[ ! -x "$pi_bin" ]]; then
		echo "Installing pi-agent..."
		require_command npm
		npm install -g @earendil-works/pi-coding-agent
		[[ -x "$pi_bin" ]] || {
			echo "Pi installation did not create $pi_bin" >&2
			return 1
		}
		# Install Pi extensions using the binary we just installed; it may not yet be on PATH.
		"$pi_bin" install npm:pi-mcp-adapter
		"$pi_bin" install npm:pi-web-access
		"$pi_bin" install npm:pi-cache-optimizer
		# rtk-optimizer needs RTK_DB_PATH available in future shells.
		"$pi_bin" install npm:pi-rtk-optimizer
		pi_config_rtk_optimizer
		"$pi_bin" install npm:@alexanderfortin/pi-token-usage
		"$pi_bin" install npm:@benvargas/pi-claude-code-use
		"$pi_bin" install npm:@gotgenes/pi-permission-system
		pi_config_permission_system
		"$pi_bin" install npm:pi-subagents
		# Install context-mode for Pi, which allows it to manage context more effectively.
		npm install -g context-mode
		"$pi_bin" install npm:context-mode
		echo add to ~/.pi/agent/mcp.json
		cat <<-EOF 
		{
		  "mcpServers": {
		    "context-mode": {
		      "command": "context-mode"
		    }
		  }
		}
		EOF
		# install codegraph
		"$pi_bin" install npm:@vndv/pi-codegraph
	else
		echo "pi-agent is already installed."
	fi
}

install_hermes_agent() {
	if is_yes "$FORCE_INSTALL" || [[ ! -x "$hermes_bin" ]]; then
		echo "Installing hermes-agent..."
		require_command curl
		curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
	else
		echo "hermes-agent is already installed."
	fi
}

claude_config_permissions() {
	if [[ ! -x "$claude_bin" ]]; then
		echo "Skipping Claude permission configuration because Claude is not installed."
		return
	fi

	local settings_path="$HOME/.claude/settings.json"
	if [[ -f "$settings_path" ]] && ! is_yes "$FORCE_INSTALL"; then
		echo "Claude settings already exist; preserving them (use --force to replace them)."
		return
	fi
	create_directory "$(dirname "$settings_path")"
	require_command jq

	# See https://code.claude.com/docs/en/settings#permission-rule-syntax

	# use jq to add allowed paths and bash commands to the settings.json file, preserving existing entries
	local path_allow_json=$(to_json "${path_allow[@]}")
	local path_deny_json=$(to_json "${path_deny[@]}")
	local bash_allow_json=$(to_json "${bash_allow[@]}")
	local bash_deny_json=$(to_json "${bash_deny[@]}")

	if ! jq --argjson path_allow "$path_allow_json" \
			--argjson path_deny "$path_deny_json" \
			--argjson bash_allow "$bash_allow_json" \
			--argjson bash_deny "$bash_deny_json" '
			.permissions |= (. // { "allow": [], "deny": [] })
			| .permissions.allow |= . + ($bash_allow | map("Bash(\(.) *)"))
			| .permissions.deny |= . + ($bash_deny | map("Bash(\(.) *)"))
			| .permissions.allow |= . + ($bash_allow | map("Bash(rtk \(.) *)"))
			| .permissions.deny |= . + ($bash_deny | map("Bash(rtk \(.) *)"))
			| .permissions.allow |= . + ($path_allow | map("Write(\(.))"))
			| .permissions.deny |= . + ($path_deny | map("Read(\(.))"))
			' > "$settings_path" <<-'EOF'
		{
			"$schema": "https://json.schemastore.org/claude-code-settings.json",
			"sandbox": {
				"enabled": false,
				"failIfUnavailable": false
			},
			"permissions": {
				"allow": [
				],
				"deny": [
				]
			}
		}
		EOF
	then
		echo "Failed to write Claude settings." >&2
		return 1
	fi
}

install_claude_agent() {
	if is_yes "$FORCE_INSTALL" || [[ ! -x "$claude_bin" ]]; then
		echo "Installing claude-agent..."
		require_command curl
		curl -fsSL https://claude.ai/install.sh | bash
	else
		echo "claude-agent is already installed."
	fi
}

to_lowercase() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

normalize_choice() {
	local value
	value="$(to_lowercase "$1")"
	case "$value" in
		y|yes) printf 'y' ;;
		n|no) printf 'n' ;;
		*)
			printf 'Expected y or n for %s; received %q\n' "$2" "$1" >&2
			return 2
			;;
	esac
}

answers() {
	INSTALL_OH_MY_BASH="$(normalize_choice "${INSTALL_OH_MY_BASH:-y}" INSTALL_OH_MY_BASH)"
	INSTALL_PI="$(normalize_choice "${INSTALL_PI:-y}" INSTALL_PI)"
	INSTALL_HERMES="$(normalize_choice "${INSTALL_HERMES:-n}" INSTALL_HERMES)"
	INSTALL_CLAUDE="$(normalize_choice "${INSTALL_CLAUDE:-n}" INSTALL_CLAUDE)"
	INSTALL_NPM="$(normalize_choice "${INSTALL_NPM:-y}" INSTALL_NPM)"
	INSTALL_RUST="$(normalize_choice "${INSTALL_RUST:-n}" INSTALL_RUST)"
	INSTALL_GO="$(normalize_choice "${INSTALL_GO:-n}" INSTALL_GO)"
	FORCE_INSTALL="$(normalize_choice "${FORCE_INSTALL:-n}" FORCE_INSTALL)"
}

get_default() {
	# return Y/n for yes, N/y for no
	case "$1" in
		y|Y)
			echo "(Y/n)"
			;;
		*)
			echo "(N/y)"
			;;
	esac
}

ask_choice() {
	local variable="$1"
	local prompt="$2"
	local reply
	local default="${!variable}"

	read -r -p "$prompt $(get_default "$default") " reply || reply=""
	if [[ -n "$reply" ]]; then
		printf -v "$variable" '%s' "$reply"
	fi
}

ask_install_choice() {
	echo "Select which components you want to install. Answer y or n."
	ask_choice INSTALL_OH_MY_BASH "Install Oh My Bash?"
	ask_choice INSTALL_PI "Install pi-agent?"
	ask_choice INSTALL_HERMES "Install hermes-agent?"
	ask_choice INSTALL_CLAUDE "Install claude-agent?"
	ask_choice INSTALL_NPM "Install common npm packages?"
	ask_choice INSTALL_RUST "Install Rust?"
	ask_choice INSTALL_GO "Install Go?"
	ask_choice FORCE_INSTALL "Force installation (overwrite existing)?"

	answers
}

run_install() {
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

	if is_yes "$INSTALL_PI" || is_yes "$INSTALL_HERMES" || is_yes "$INSTALL_CLAUDE"; then
		install_rtk
	else
		echo "Skipping RTK installation because no agent was selected."
	fi
}

setup_complete() {
	echo "Setup complete. Please restart your terminal or run 'bash' to apply changes."
}

usage() {
	cat <<EOF
Usage: ${0##*/} [options]

Options:
  -f, --force           Force installation (overwrite existing)
  --agent <agent>       Enable an agent install (pi, hermes, claude)
  --permissions         Configure permissions for installed Pi and Claude agents
  -h, --help            Show this help message
EOF
}

configure_permissions() {
	pi_config_permission_system
	pi_config_rtk_optimizer
	claude_config_permissions
}

# Set default answers if not already set.
answers

if [[ $# -eq 0 ]]; then
	ask_install_choice
	run_install
	setup_complete
	exit 0
fi

install_requested=false
permissions_requested=false
force_requested=false
while [[ $# -gt 0 ]]; do
	case "$1" in
		-f|--force)
			FORCE_INSTALL="y"
			force_requested=true
			shift
			;;
		--agent)
			if [[ $# -lt 2 || -z "$2" ]]; then
				echo "--agent requires one of: pi, hermes, claude." >&2
				exit 2
			fi
			INSTALL_PI="n"
			INSTALL_HERMES="n"
			INSTALL_CLAUDE="n"
			case "$(to_lowercase "$2")" in
				pi) INSTALL_PI="y" ;;
				hermes) INSTALL_HERMES="y" ;;
				claude) INSTALL_CLAUDE="y" ;;
				*)
					echo "Unknown agent: $2. Valid options are: pi, hermes, claude." >&2
					exit 2
					;;
			esac
			install_requested=true
			shift 2
			;;
		--permissions)
			permissions_requested=true
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

# --force alone means a forced default installation; with only --permissions it
# instead authorizes replacing the generated permission configuration.
if [[ "$force_requested" == true && ( "$permissions_requested" != true || "$install_requested" == true ) ]]; then
	install_requested=true
fi

if [[ "$install_requested" == true ]]; then
	run_install
	setup_complete
fi
if [[ "$permissions_requested" == true ]]; then
	configure_permissions
	if [[ "$install_requested" != true ]]; then
		echo "Permission configuration complete. Restart your terminal to apply RTK_DB_PATH."
	fi
fi
