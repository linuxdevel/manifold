# Docker Isolation Documentation Design

## Goal

Document the work-in-progress Docker launcher as a more isolated way to run Manifold without overstating its security. Current runtime support is limited to Copilot, and the launcher has only been tested on WSL2. Native Linux remains unvalidated; macOS is unsupported for now.

## Documentation Structure

- Keep the full security-first guide in `docker/README.md`.
- Keep the root `README.md` focused on Manifold, with a short Docker isolation section linking to the canonical guide.
- Cover support status, prerequisites, quick start, host mounts, credential handling, isolation controls, known weaknesses, cleanup, and troubleshooting.

## Security Language

Describe Docker as limiting mounted host paths, not as a complete security boundary. Explicitly disclose that the launcher currently uses Electron `--no-sandbox`, `seccomp=unconfined`, `SYS_ADMIN`, `SYS_PTRACE`, and local X11 access. Explain that the Copilot credential mount and Manifold app-data volume contain sensitive data.

Recommend mounting the smallest practical workspace and protecting Docker daemon access. Document that `--no-copilot` currently disables Copilot; a container-only credential store is future work.

## Verification

- Check every documented command, path, mount, flag, and limitation against `docker/manifold-docker.sh` and `docker/Dockerfile`.
- Run documentation structural checks.
- Request an independent factual and container-security review.
