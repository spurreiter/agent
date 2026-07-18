# Agent Sandbox

A containerized sandbox for running AI agents in an isolated environment. Defaults to [pi][pi.dev] but can also set up Hermes and Claude agents.

## Overview

This repository provides a lightweight Docker-based environment for running agents with a consistent development setup. It includes:

- **Docker container** with Node.js LTS and essential development tools
- **Multi-agent support** with options for pi, Hermes, Claude, and OpenDev agents
- **Interactive setup script** to customize your environment
- **Volume mounts** for persistent home directory, npm cache, and workspace
- **Helper scripts** to simplify building, setup, and execution

### Key Features

- **Isolated Environment**: Run agents safely in a containerized sandbox
- **Development Tools**: Includes git, ripgrep, fd-find, vim, neovim, golang, Python 3, Rust support
- **Agent Ecosystem**: Pre-configured with popular AI agent frameworks
- **Persistent Storage**: Home directory and npm cache persist between runs
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
- Pull the official Node.js LTS image (krypton)
- Build the agent image with development tools
- Initialize the home directory with default configuration files

### 3. Run initial setup (interactive)

```sh
./agent.sh --setup
```

You'll be prompted to install:
- **Oh My Bash** - Enhanced shell configuration (default: yes)
- **pi-agent** - Pi coding agent (default: yes)
- **hermes-agent** - Hermes AI agent (default: no)
- **claude-agent** - Claude integration (default: no)
- **npm packages** - Utilities like prettier, pnpm, and tools (default: yes)
- **Rust** - Rust toolchain (default: no)

Additional components like RTK (agent initialization tool) are installed automatically when needed.

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

The `./home` directory persists between container runs and contains:

- **`.npmrc`** - npm configuration for global installations to `~/.local/share/npm`
- **`.local/share/npm/bin/`** - Global npm binaries
- **`.local/bin/`** - User-installed binaries
- **`.oh-my-bash/`** - Shell configuration (if installed)
- **Agent configs** - Pi, Hermes, Claude configuration files

All files from `./files/` are copied to `./home/` on first initialization.


## Setup Script Details

The interactive setup script (`./build/setup.sh`) performs:

### Agent Installation

- **pi-agent** - Installs [@earendil-works/pi-coding-agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) globally with packages:
  - [pi-mcp-adapter](https://www.npmjs.com/package/pi-mcp-adapter) - MCP protocol support
  - [pi-web-access](https://www.npmjs.com/package/pi-web-access) - Web browsing capabilities
  - [pi-rtk-optimizer](https://www.npmjs.com/package/pi-rtk-optimizer) - RTK optimization (needs [RTK](https://www.rtk-ai.app/))
  - [pi-cache-optimizer](https://www.npmjs.com/package/pi-cache-optimizer) - Cache optimizer
  - [@alexanderfortin/pi-token-usage](https://www.npmjs.com/package/@alexanderfortin/pi-token-usage) - Token tracking

- **hermes-agent** - Installs from Nousresearch
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
| `./home` | `/home/node` | Persistent home directory |
| `~/.npm` (host cache) | `/home/node/.npm` | npm cache |
| Current/specified directory | `/home/node/ws` | Working directory |

This ensures:
- Persistent configuration and installed packages across runs
- Shared npm cache for faster package downloads
- Access to local files from the container


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

Edit `./build/dockerfile` to add tools, then rebuild:

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
