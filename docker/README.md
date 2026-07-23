# Running Manifold with Docker Isolation

> [!WARNING]
> This Docker setup is a work in progress. It reduces which host files Manifold
> can access, but it is not a hardened sandbox. Only GitHub Copilot is currently
> supported. The setup has been tested on x64 WSL2 with WSLg; native Linux has
> not yet been validated, and macOS is not supported.

## What This Protects

The launcher exposes only selected host paths to Manifold instead of running the
application with access to your entire home directory. This limits the files a
compromised or misbehaving agent can read or modify through ordinary filesystem
access.

Docker does not make an AI agent inherently safe. Copilot still receives the
prompts and repository data needed to answer requests, the container has normal
outbound network access, and the current Electron compatibility settings weaken
several Docker isolation controls. Read [Known limitations](#known-limitations)
before relying on this setup for sensitive code.

## Support Status

| Item | Status |
| --- | --- |
| WSL2 x64 with WSLg | Tested |
| Native Linux x64 | Not yet validated |
| macOS | Not supported |
| GitHub Copilot CLI | Supported |
| Claude Code, Codex, Gemini, Ollama | Not supported by this launcher yet |

## Prerequisites

- Docker installed and running inside or accessible from WSL2
- WSLg, or an X11 display available through `DISPLAY`
- Manifold built and installed with `bash install-linux.sh`
- GitHub Copilot CLI installed at `~/.local/bin/copilot`
- Existing Copilot credentials under `~/.copilot`

Confirm the required host files before starting:

```bash
test -x ~/.local/share/manifold/manifold
test -x ~/.local/bin/copilot
test -d ~/.copilot
docker version
```

## Quick Start

Run the launcher from the Manifold repository and mount the smallest directory
that Copilot needs for the task:

```bash
bash docker/manifold-docker.sh --workspace ~/projects/myapp
```

The first run builds `manifold-sandbox:latest`. Rebuild after changing
`docker/Dockerfile` or when you want to refresh the image:

```bash
bash docker/manifold-docker.sh --workspace ~/projects/myapp --rebuild
```

Use `--no-copilot` to start Manifold without mounting either the host Copilot
credentials or the Copilot binary. In the current implementation this disables
Copilot; container-local authentication is not implemented yet.

```bash
bash docker/manifold-docker.sh --workspace ~/projects/myapp --no-copilot
```

## Host Access

The launcher creates these mounts:

| Host or Docker source | Container path | Access | Security impact |
| --- | --- | --- | --- |
| `~/.local/share/manifold` | `/opt/manifold` | Read-only | Exposes the installed Manifold package |
| Selected workspace | `/workspace` | Read/write | Copilot can read and modify every file under this directory |
| `~/.copilot` | `/home/appuser/.copilot` | Read/write | Exposes Copilot credentials; token refreshes affect the host copy |
| `~/.local/bin/copilot` | `/usr/local/bin/copilot` | Read-only | Exposes the host Copilot executable |
| X11 socket | `/tmp/.X11-unix` | Read/write | Allows the GUI to reach the host display server |
| Xauthority file, when present | `/tmp/.docker.xauth` | Read-only | Exposes the X11 authentication cookie |
| `manifold-sandbox-appdata` volume | `/home/appuser/.manifold` | Read/write | Persists Manifold settings, logs, chat data, and managed worktrees |

No Docker socket, host root filesystem, or complete home directory is mounted by
the launcher. This statement applies only to explicit mounts; the container
still has network access and shares the host kernel through Docker.

## Existing Isolation Controls

The current launcher:

- runs Manifold as the invoking host UID and GID rather than as root;
- drops Linux capabilities before adding only the compatibility capabilities
  listed below;
- mounts the installed Manifold package and Copilot executable read-only;
- confines writable host access to the selected workspace and Copilot credential
  directory;
- stores Manifold application data in a Docker-managed volume;
- removes the container automatically when Manifold exits.

## Known Limitations

This is not a hardened or production-grade sandbox:

- Electron runs with `--no-sandbox`, so Chromium's internal sandbox is disabled.
- Docker's seccomp filtering is disabled with `--security-opt seccomp=unconfined`.
- The container receives `SYS_ADMIN` and `SYS_PTRACE`; `SYS_ADMIN` is especially
  broad and significantly weakens the container boundary.
- The launcher runs `xhost +local:`, allowing local processes to connect to the
  X server. X11 was not designed as a strong security boundary, and this access
  remains until revoked.
- The workspace and host Copilot credential directory are writable from the
  container. A compromised process could alter workspace files or credentials.
- Outbound network access is unrestricted. Docker isolation does not prevent an
  agent from sending data to services it is authorized or tricked into using.
- The image uses the mutable `ubuntu:24.04` tag and is not pinned by digest.
- The host-installed Manifold and Copilot binaries are trusted without signature
  or checksum verification by the launcher.
- There are no CPU, memory, process-count, or network resource limits.

## Safer Usage

- Mount a task-specific repository or subdirectory, not your home directory or a
  broad projects folder.
- Do not use this setup for repositories containing secrets or data that Copilot
  is not permitted to process.
- Keep secrets outside the mounted workspace. Do not place `.env`, key, or
  credential files under the selected directory.
- Treat `~/.copilot` and the `manifold-sandbox-appdata` volume as sensitive.
- Protect access to the Docker daemon. A user who controls Docker effectively has
  host-level control regardless of this launcher.
- Review changes before committing or running generated code.
- Revoke the broad local X11 permission after Manifold exits:

```bash
xhost -local:
```

- Use `--no-copilot` when you only need to inspect Manifold without agent access.
  A dedicated container-only Copilot credential store is future work.

## Persistent Data and Cleanup

Stopping Manifold removes the container, but it does not remove the image or the
named application-data volume.

Inspect the persistent volume:

```bash
docker volume inspect manifold-sandbox-appdata
```

Delete the application-data volume when its saved settings, logs, chat history,
and worktrees are no longer needed. This is irreversible:

```bash
docker volume rm manifold-sandbox-appdata
```

Delete the locally built image when it is no longer needed:

```bash
docker image rm manifold-sandbox:latest
```

## Troubleshooting

### The window does not open

Verify that WSLg/X11 is available and `DISPLAY` is set:

```bash
printf '%s\n' "$DISPLAY"
ls -ld /tmp/.X11-unix
```

### Copilot is unavailable

The launcher only mounts Copilot from `~/.local/bin/copilot`. Confirm that exact
path exists and that the CLI works on the host:

```bash
~/.local/bin/copilot --version
```

### Docker changes do not take effect

The existing image is reused by default. Run the launcher with `--rebuild` after
changing the Dockerfile.

### DBus, GPU, or Crashpad warnings appear

Electron can emit warnings about DBus, GPU features, or CPU frequency files in a
container. These warnings are not by themselves proof that Manifold crashed.
Check whether the window remains open and inspect the container exit behavior
before diagnosing them as the root cause.

## Security Roadmap

Before describing this as a hardened sandbox, the launcher should remove
`seccomp=unconfined`, `SYS_ADMIN`, and `SYS_PTRACE`; avoid broad `xhost` access;
support container-local credentials; add resource and network controls; and pin
and verify the image and mounted binaries. Other agent runtimes require separate
mount, credential, and behavior review before they are supported.
