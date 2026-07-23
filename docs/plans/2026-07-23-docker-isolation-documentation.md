# Docker Isolation Documentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish accurate security-first guidance for the work-in-progress, Copilot-only Docker launcher.

**Architecture:** `docker/README.md` is the canonical operational and security guide. The root `README.md` retains the general project documentation and links to that guide from a short Docker section.

**Tech Stack:** Markdown, Docker, Bash, Electron on Linux/WSL2

---

### Task 1: Restore the root project guide and add the Docker entry point

**Files:**
- Modify: `README.md`

**Step 1:** Restore the tracked general Manifold README content without disturbing unrelated current project documentation.

**Step 2:** Add a concise `Docker isolation (work in progress)` section stating that only Copilot is currently supported, WSL2 is tested, native Linux is not yet validated, and the full guide lives at `docker/README.md`.

### Task 2: Write the canonical security-first Docker guide

**Files:**
- Modify: `docker/README.md`

**Step 1:** Add support status and prerequisites for WSL2/Linux, explicitly excluding macOS for now.

**Step 2:** Document the verified quick-start command and rebuild option.

**Step 3:** Document each host bind mount and the named app-data volume, including access modes and sensitive-data implications.

**Step 4:** Explain existing isolation controls and disclose weakened controls: Electron `--no-sandbox`, `seccomp=unconfined`, `SYS_ADMIN`, `SYS_PTRACE`, local X11 access, network access, and read/write credentials.

**Step 5:** Add safer-use recommendations, credential choices, cleanup commands, and concise troubleshooting for display, missing Copilot binary, and rebuilds.

### Task 3: Verify documentation

**Files:**
- Verify: `README.md`
- Verify: `docker/README.md`

**Step 1:** Compare every documented command, mount, and flag against `docker/manifold-docker.sh` and `docker/Dockerfile`.

**Step 2:** Run `scripts/wiki-lint.sh` and record structural results separately from pre-existing stale pages.

**Step 3:** Run `git diff --check`.

**Step 4:** Request an independent factual and container-security review, then address any important findings.
