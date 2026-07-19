#!/usr/bin/env bash

set -euo pipefail

CWD=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
WORK_DIR="$(pwd)"
IMAGE_NAME="agent:latest"

show_help() {
	cat <<EOF
$IMAGE_NAME - A Docker image for running agents.

Usage:
  $0 [OPTIONS] [COMMAND]

Options:
  -h, --help        Show this help message and exit
  -b, --build       Build the Docker image.
  -s, --setup		Run the setup script inside the Docker image.
  -d, --dir <path>  Specify the working directory to mount inside the container.
      --reset	    Reset the working directory to a clean state and start the setup script.
      --bin 		Output a shell script that runs this agent.sh script.

EOF
}

prepare_home() {
	if [ ! -d "$CWD/home" ]; then
		mkdir -p "$CWD/home"
		chmod 777 "$CWD/home"
		
		# create common user directories for npm and cargo
		# PATH must be set in the Dockerfile to include these directories for global installations
		mkdir -p "$CWD/home/.cargo/bin"
		mkdir -p "$CWD/home/.local/bin"
		mkdir -p "$CWD/home/.local/share/go/bin"
		mkdir -p "$CWD/home/.local/share/npm/bin"

		# prepare .npmrc for global installations
		cat <<-EOF > "$CWD/home/.npmrc"
		prefix=~/.local/share/npm
		ignore-scripts=true
		min-release-age=2
		EOF
		# copy over default files to home directory
		# e.g. agent authentication files, config files, etc.
		cp -rf "$CWD/files/." "$CWD/home/"
	fi
}

build_image() {
	cd "$CWD"
	docker pull node:lts-krypton
	echo "Building $IMAGE_NAME image…"
	# Prefer BuildKit with buildx when available for verbose/plain progress
	if command -v docker >/dev/null 2>&1 && docker buildx version >/dev/null 2>&1; then
		echo "Buildx available — using BuildKit with plain progress"
		DOCKER_BUILDKIT=1 docker build --progress=plain -t "$IMAGE_NAME" -f ./build/dockerfile "$CWD/build"
	else
		echo "Buildx not available — falling back to standard docker build"
		docker build -t "$IMAGE_NAME" -f ./build/dockerfile "$CWD/build"
	fi
	prepare_home
}

ensure_image() {
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
		build_image
    fi
}

run_image() {
	ensure_image
	prepare_home
    local ws="/home/node/ws"

	docker run --rm -it \
	--add-host host.docker.internal:host-gateway \
	-e "PNPM_HOME=/home/node/.pnpm-store/v11" \
	-e "npm_config_cache=/home/node/.npm" \
	-e "PI_WORKSPACE=$ws" \
	-w "$ws" \
	-v "$CWD/home:/home/node" \
	-v "$WORK_DIR:$ws" \
	-v "$CWD/build/setup.sh:/usr/local/bin/setup.sh" \
	"$IMAGE_NAME" "$@"
}

## for dev of the setup script, you can mount the local setup.sh into the container to test changes without rebuilding the image:
#	-v "$CWD/build/setup.sh:/usr/local/bin/setup.sh" \

if [[ $# -eq 0 ]]; then
	run_image bash
else
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-b|--build)
				build_image
				exit 0
				;;
			-s|--setup)
				ensure_image
				run_image setup.sh
				exit 0
				;;
			-h|--help)
				show_help
				exit 0
				;;
			-d|--dir)
				WORK_DIR="$2"
				shift 2
				;;
			--reset)
				test -d "$CWD/home" && rm -rf "$CWD/home"
				run_image setup.sh
				exit 0
				;;
			--bin)
				cat <<-EOF
				#!/usr/bin/env bash
				$CWD/agent.sh "\$@"
				EOF
				exit 0
				;;
			*)
				run_image "$@"
				break
				;;
		esac
	done
fi
