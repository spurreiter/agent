# Agent Sandbox

A containerized sandbox for running AI agents in an isolated environment. It defaults to [pi][pi.dev] and can optionally set up Claude.

## Overview

This repository provides a lightweight Docker-based environment for running agents with a consistent development setup. It includes:

- **Docker container** with Node.js 26, Go, Rust, Python, Java, PlantUML, Graphviz, and essential development tools
- **Multi-agent support** with options for pi and Claude agents
- **Interactive setup script** to customize your environment
- **Volume mounts** for persistent home directory and workspace
- **Hardened runtime** with a read-only container, dropped capabilities, resource limits, and isolated temporary filesystems
- **Helper scripts** to simplify building, setup, and execution

### Key Features

- **Isolated Environment**: Run agents safely in a containerized sandbox
- **Development Tools**: Includes git, ripgrep, fd-find, vim, tmux, jq, tree, Go, Rust, Python 3, Java, PlantUML, Graphviz, and RTK
- **Agent Ecosystem**: Pre-configured with pi extensions and optional Claude integration
- **Persistent Storage**: Home directory, npm cache, and package-manager data persist between runs
- **Cross-Platform**: Supports both x86_64 and aarch64 architectures


## Quick Start

### 1. Clone the repository

```sh
git clone https://github.com/spurreiter/agent
cd agent
```

### 2. Build the Docker image

```sh
./agent.sh --build
```

This will:
- Pull the configured Ubuntu base image (Ubuntu 26.10 by default)
- Build an agent image with development tools and preinstalled runtimes
- Create the image's non-root `agent` user using the host user's UID
- Initialize the home directory with default configuration files

### 3. Run initial setup (interactive)

```sh
./agent.sh --setup
```

You'll be prompted to install:
- **Oh My Bash** - Enhanced shell configuration (default: yes)
- **pi-agent** - Pi coding agent and extensions (default: yes)
- **claude-agent** - Claude integration (default: no)
- **npm packages** - CodeGraph, OpenSpec, pnpm, Prettier, Skills, and sort-package-json (default: yes)
- **Force installation** - Replace existing agent configuration (default: no)

The image already contains RTK, Node.js, Go, Rust, Python, Java, PlantUML, and Graphviz. RTK is initialized automatically when pi or Claude is installed.

### 4. Run the agent

```sh
# Run pi agent with bash in current directory
./agent.sh pi

# Run pi agent in a specific directory
./agent.sh -d /tmp pi

# Run bash shell with full access
./agent.sh bash

# Run any command in the container
./agent.sh pi --version
```


## Commands Reference

### Build and Setup

| Command | Description |
|---------|-------------|
| `./agent.sh --build` | Build the Docker image |
| `./agent.sh --setup` | Run interactive setup wizard |
| `./agent.sh --reset` | Reset home directory and run setup |

### Runtime Options

| Option | Description |
|--------|-------------|
| `-d, --dir <path>` | Mount a directory as the working directory (default: current directory) |
| `-h, --help` | Show help message |
| `--bin` | Generate a standalone startup script |

### Examples

```sh
# Run pi in a specific directory
./agent.sh -d /tmp pi

# Run hermes with custom working directory
./agent.sh -d ~/projects hermes

# Create a standalone agent script in your PATH
./agent.sh --bin > ~/bin/agent
chmod u+x ~/bin/agent

# Then run from anywhere:
agent pi
```


## Directory Structure

```
.
├── agent.sh              # Main entry point script
├── readme.md             # This file
├── LICENSE               # MIT License
├── build/
│   ├── dockerfile        # Docker image configuration
│   └── setup.sh          # Interactive setup script
├── home/                 # Persistent home directory (created on first run)
│   ├── .npmrc            # npm global config
│   ├── .local/           # User-local binaries and npm packages
│   └── ...               # Other configuration files
└── files/                # Template files for home directory
    └── ...               # Default configuration templates
```

### Home Directory (`./home`)

The `./home` directory is mounted at `/home/agent` and persists between container runs. It contains:

- **`.npmrc`** - npm configuration for global installations to `~/.local/share/npm`
- **`.local/share/npm/bin/`** - Global npm binaries
- **`.local/bin/`** - User-installed binaries
- **`.oh-my-bash/`** - Shell configuration (if installed)
- **Agent configs** - Pi and Claude configuration files

All files from `./files/` are copied to `./home/` on first initialization. The workspace is mounted at `/home/agent/ws`.


## Setup Script Details

The interactive setup script (`./build/setup.sh`) performs:

- Configures conservative path and shell-command permissions for pi and Claude, including broad read-only and diagnostic command access while denying destructive or network-sensitive commands.
- Preserves existing agent configuration unless force installation is selected.

### Agent Installation

- **pi-agent** - Installs [@earendil-works/pi-coding-agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) globally with extensions:
  - [pi-mcp-adapter](https://www.npmjs.com/package/pi-mcp-adapter) - MCP protocol support
  - [pi-web-access](https://www.npmjs.com/package/pi-web-access) - Web browsing capabilities
  - [pi-rtk-optimizer](https://www.npmjs.com/package/pi-rtk-optimizer) - RTK optimization (needs [RTK](https://www.rtk-ai.app/))
  - [pi-cache-optimizer](https://www.npmjs.com/package/pi-cache-optimizer) - Cache optimizer
  - [@alexanderfortin/pi-token-usage](https://www.npmjs.com/package/@alexanderfortin/pi-token-usage) - Token tracking
  - [@benvargas/pi-claude-code-use](https://www.npmjs.com/package/@benvargas/pi-claude-code-use) - Claude Code integration (in case you want to use a max/pro plan)
  - [@gotgenes/pi-permission-system](https://www.npmjs.com/package/@gotgenes/pi-permission-system) - Granular permission system with safe defaults
  - [pi-subagents](https://www.npmjs.com/package/pi-subagents) - Delegate work to focused child agents
  - [context-mode](https://www.npmjs.com/package/context-mode) - Manage context efficiently
  - `@vndv/pi-codegraph` - CodeGraph project navigation
- **claude-agent** - Installs Claude integration

### RTK Integration

After agent installation, the setup initializes agents using RTK (Agent Initialization Tool):
- `rtk init --agent {agent}`

### npm Packages

Common development utilities installed globally:
- `prettier` - Code formatter
- `@fission-ai/openspec` - OpenAPI spec tools
- `skills` - Skills management
- `pnpm` - Fast package manager

### Shell Configuration

- **Oh My Bash** - Enhanced bash configuration with themes and plugins


## Volume Mounts

The agent container mounts:

| Host Path | Container Path | Purpose |
|-----------|-----------------|---------|
| `./home` | `/home/agent` | Persistent home directory |
| Current/specified directory | `/home/agent/ws` | Working directory |
| `./build/setup.sh` | `/usr/local/bin/setup.sh` (read-only) | Setup script |

This ensures:
- Persistent configuration and installed packages across runs
- Access to local files from the container
- A read-only container root filesystem; writable state is kept in mounted directories and limited tmpfs mounts
- Container limits of 4 GiB memory, 2 CPUs, and 512 processes


## Customization

### Add Local Configuration

Place configuration files or credentials in the `./files/` directory. These will be copied to `./home/` during initialization:

```sh
# Example: reuse pi models
mkdir -p ./files/.pi/agent
cp ~/.pi/agent/models.json ./files/.pi/agent

# Initialize or reset
./agent.sh --reset
```

### Install Additional Packages

To add npm packages globally, install them inside the container:

```sh
./agent.sh npm install -g <package-name>
```

They will persist in `./home/.local/share/npm/bin/`.

### Modify the Container

Edit `./build/dockerfile` to add tools, then rebuild. The Dockerfile accepts `FROM_IMAGE`, `USER_ID`, `ARCH`, and `network` build arguments. Set `network=false` to omit the optional network tool (`socat`); build-time downloads still require network access:

```sh
./agent.sh --build
```

### Creating a Standalone Script

Generate a standalone script that can be placed in your PATH:

```sh
./agent.sh --bin > ~/bin/agent
chmod u+x ~/bin/agent

# Ensure ~/bin is in your PATH
export PATH=$HOME/bin:$PATH
```

Then run from anywhere:

```sh
agent -d /tmp pi
```


## Resetting the Agent

To return the container to a clean state:

```sh
./agent.sh --reset
```

This will:
- Remove the `./home` directory completely
- Re-initialize from `./files/` templates
- Run the setup wizard again


## License & Contributing

This project is published under the **MIT License**. You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the software, subject to the terms in the [LICENSE](LICENSE) file.

Feel free to:
- Fork and adapt the project
- Submit pull requests with improvements
- Report issues and suggest features


## See Also

- [pi documentation][pi.dev] - Pi coding agent documentation
- [Oh My Bash](https://ohmybash.github.io/) - Bash configuration framework

[pi.dev]: https://pi.dev
