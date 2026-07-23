FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Electron/Chromium runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # X11 / display
    libx11-6 libxext6 libxrandr2 libxcomposite1 libxcursor1 libxdamage1 \
    libxfixes3 libxi6 libxrender1 libxtst6 libxss1 libglib2.0-0 \
    # OpenGL / Mesa
    libgl1-mesa-dri libegl1 libgles2 \
    # Fonts / ICU
    fonts-liberation libfontconfig1 libfreetype6 libpango-1.0-0 libpangocairo-1.0-0 \
    # Audio (optional but avoids Chromium warnings)
    libasound2t64 \
    # Chromium sandbox support
    libcap2-bin \
    # GTK3 and related GUI toolkit (required by Electron)
    libgtk-3-0 libgdk-pixbuf2.0-0 libcairo2 libcairo-gobject2 \
    libharfbuzz0b \
    # Misc shared libs Electron expects
    libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcups2 libdbus-1-3 \
    libdrm2 libgbm1 libnspr4 libnss3 libpulse0 libxkbcommon0 \
    # node-pty / shell inside Manifold
    bash zsh curl git ca-certificates \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user that mirrors the host UID/GID (overridden at runtime)
ARG UID=1000
ARG GID=1000
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    groupadd -g "${GID}" appuser && \
    useradd -u "${UID}" -g "${GID}" -m -s /bin/bash appuser && \
    mkdir -p /home/appuser/.manifold && \
    chown appuser:appuser /home/appuser/.manifold

# Manifold binary is mounted at runtime; just create the expected mount point.
RUN mkdir -p /opt/manifold /workspace
RUN chown appuser:appuser /workspace

USER appuser
WORKDIR /workspace

# Entrypoint: launch Manifold with flags required for containerised Chromium.
# --no-sandbox              : user-namespace isolation not available inside Docker
# --disable-dev-shm-usage   : /dev/shm may be tiny; route to /tmp instead
# --disable-gpu             : disable hardware GPU rendering; prevents a GPU subprocess from
#                             spawning and crashing on chat re-render.  Do NOT add
#                             --in-process-gpu alongside this: running GPU work in-process
#                             means any GPU fault becomes a SIGSEGV that kills the whole app.
# --disable-gpu-compositing : disable GPU compositing (belt-and-suspenders with --disable-gpu)
# --ozone-platform=x11      : stable XWayland path (mirrors host wrapper)
ENTRYPOINT ["/opt/manifold/manifold", \
  "--no-sandbox", \
  "--disable-dev-shm-usage", \
  "--disable-gpu", \
  "--disable-gpu-compositing", \
  "--ozone-platform=x11"]
CMD []
