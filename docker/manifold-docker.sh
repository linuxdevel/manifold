#!/usr/bin/env bash
# manifold-docker.sh  — Run Manifold in an isolated Docker container.
#
# Usage:
#   ./docker/manifold-docker.sh [OPTIONS] [-- MANIFOLD_ARGS...]
#
# Options:
#   -w, --workspace DIR   Host directory to mount as /workspace (required)
#   -n, --name NAME       Container name  (default: manifold-sandbox)
#   -i, --image NAME      Docker image tag (default: manifold-sandbox:latest)
#   --rebuild             Force rebuild of the Docker image
#   --no-copilot          Do not mount Copilot credentials into the container
#   -h, --help            Show this help
#
# Examples:
#   ./docker/manifold-docker.sh --workspace ~/projects/myapp
#   ./docker/manifold-docker.sh -w ~/projects/myapp -- --disable-gpu
#
# Copilot auth
# -----------
# By default the script mounts ~/.copilot/ (read-write) so the token Manifold
# already has on the host is available inside the container.  The directory is
# bind-mounted, not copied, so any token refresh Manifold performs is written
# back to the host automatically.
#
# Pass --no-copilot to omit both the host credentials and Copilot binary. This
# disables Copilot; container-local authentication is not implemented yet.
#
# Security model
# --------------
# • WORKSPACE and ~/.copilot are writable host bind mounts; the latter is omitted
#   with --no-copilot. Manifold app data is writable in a Docker named volume.
# • The mounted Manifold package and Copilot binary are read-only, but executable.
# • X11 display resources are exposed when available; no full home/root mount or
#   Docker socket is added by this launcher.
# • The container runs as the current user (matching host UID/GID).
# • Electron uses --no-sandbox. Docker isolation is also weakened by
#   seccomp=unconfined plus SYS_PTRACE and SYS_ADMIN compatibility capabilities.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="manifold-sandbox:latest"
CONTAINER_NAME="manifold-sandbox"
WORKSPACE=""
REBUILD=false
NO_COPILOT=false
EXTRA_ARGS=()

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)  WORKSPACE="$2";   shift 2 ;;
    -n|--name)       CONTAINER_NAME="$2"; shift 2 ;;
    -i|--image)      IMAGE="$2";       shift 2 ;;
    --rebuild)       REBUILD=true;     shift   ;;
    --no-copilot)    NO_COPILOT=true;  shift   ;;
    -h|--help)
      sed -n '3,50p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    --)              shift; EXTRA_ARGS=("$@"); break ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Prerequisites ─────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "Error: docker is not installed or not in PATH." >&2
  exit 1
fi

if [[ -z "$WORKSPACE" ]]; then
  echo "Error: --workspace DIR is required." >&2
  echo "  Usage: $0 --workspace /path/to/your/project" >&2
  exit 1
fi

WORKSPACE="$(realpath "$WORKSPACE")"
if [[ ! -d "$WORKSPACE" ]]; then
  echo "Error: workspace directory does not exist: $WORKSPACE" >&2
  exit 1
fi

MANIFOLD_BIN="${HOME}/.local/share/manifold"
if [[ ! -f "${MANIFOLD_BIN}/manifold" ]]; then
  echo "Error: Manifold binary not found at ${MANIFOLD_BIN}/manifold" >&2
  echo "  Build and install first:  bash install-linux.sh" >&2
  exit 1
fi

COPILOT_DIR="${HOME}/.copilot"
COPILOT_BIN="${HOME}/.local/bin/copilot"

# ── Build image ───────────────────────────────────────────────────────────────
build_image() {
  echo "Building Docker image ${IMAGE}..."
  docker build \
    --build-arg "UID=$(id -u)" \
    --build-arg "GID=$(id -g)" \
    -t "${IMAGE}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${SCRIPT_DIR}"
}

if $REBUILD || ! docker image inspect "${IMAGE}" &>/dev/null; then
  build_image
fi

# ── X11 display forwarding ────────────────────────────────────────────────────
# Works on Linux with a local X server.  On macOS you need XQuartz running and
# DISPLAY set to the host IP (e.g. host.docker.internal:0).
if [[ -z "${DISPLAY:-}" ]]; then
  echo "Warning: DISPLAY is not set. Manifold (an Electron app) needs a display." >&2
  echo "  On macOS: install XQuartz and set DISPLAY=host.docker.internal:0" >&2
fi

X11_SOCKET="/tmp/.X11-unix"
DOCKER_DISPLAY_ARGS=()
if [[ -S "${X11_SOCKET}/X${DISPLAY#:}" ]] || [[ -d "$X11_SOCKET" ]]; then
  # Allow any local process (including Docker containers) to connect to the
  # X server without auth.  +local: is broader than +local:docker and avoids
  # auth failures when the container's process label doesn't match "docker".
  if command -v xhost &>/dev/null; then
    xhost +local: 2>/dev/null || true
  fi
  DOCKER_DISPLAY_ARGS=(
    -e "DISPLAY=${DISPLAY:-:0}"
    -v "${X11_SOCKET}:${X11_SOCKET}:rw"
  )
  # Pass the X11 auth cookie if available so the container can authenticate
  # even when the X server requires MIT-MAGIC-COOKIE.
  _xauth="${XAUTHORITY:-${HOME}/.Xauthority}"
  if [[ -f "$_xauth" ]]; then
    DOCKER_DISPLAY_ARGS+=(
      -e "XAUTHORITY=/tmp/.docker.xauth"
      -v "${_xauth}:/tmp/.docker.xauth:ro"
    )
  fi
else
  echo "Warning: X11 socket not found at ${X11_SOCKET}. GUI may not work." >&2
  DOCKER_DISPLAY_ARGS=(-e "DISPLAY=${DISPLAY:-:0}")
fi

# ── Volume mounts ─────────────────────────────────────────────────────────────
MOUNTS=(
  # Installed Manifold package — executed from a read-only mount
  -v "${MANIFOLD_BIN}:/opt/manifold:ro"
  # User workspace — the ONLY writable host path inside the container
  -v "${WORKSPACE}:/workspace:rw"
)

if ! $NO_COPILOT; then
  if [[ -d "$COPILOT_DIR" ]]; then
    MOUNTS+=(-v "${COPILOT_DIR}:/home/appuser/.copilot:rw")
    echo "Mounting Copilot credentials from ${COPILOT_DIR}"
  else
    echo "Notice: ~/.copilot not found; Manifold will prompt for GitHub login on first run."
  fi
  if [[ -f "$COPILOT_BIN" ]]; then
    MOUNTS+=(-v "${COPILOT_BIN}:/usr/local/bin/copilot:ro")
    echo "Mounting Copilot binary from ${COPILOT_BIN}"
  else
    echo "Notice: copilot binary not found at ${COPILOT_BIN}; Copilot CLI will not be available."
  fi
fi

# Named volume for Manifold's own app data (window state, session DB, etc.)
# Kept separate from the host so it doesn't pollute ~/.manifold on the host.
MOUNTS+=(-v "manifold-sandbox-appdata:/home/appuser/.manifold")

# ── Run ───────────────────────────────────────────────────────────────────────
echo ""
echo "Starting Manifold in Docker"
echo "  Image     : ${IMAGE}"
echo "  Workspace : ${WORKSPACE} → /workspace"
echo "  Copilot   : $( $NO_COPILOT && echo "disabled (--no-copilot)" || echo "${COPILOT_DIR}" )"
echo ""

# Remove any previously stopped container with the same name
docker rm -f "${CONTAINER_NAME}" &>/dev/null || true

exec docker run \
  --name "${CONTAINER_NAME}" \
  --rm \
  --user "$(id -u):$(id -g)" \
  "${MOUNTS[@]}" \
  "${DOCKER_DISPLAY_ARGS[@]}" \
  -e HOME="/home/appuser" \
  -e USER="$(id -un)" \
  -e LOGNAME="$(id -un)" \
  -e GSETTINGS_BACKEND="memory" \
  -e ELECTRON_ENABLE_LOGGING=1 \
  --shm-size=2g \
  --security-opt seccomp=unconfined \
  --cap-drop ALL \
  --cap-add SYS_PTRACE \
  --cap-add SYS_ADMIN \
  "${IMAGE}" \
  "${EXTRA_ARGS[@]}"
