FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set environment to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Prevent services from starting during package installation
RUN echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

# Install PowerShell, Docker CLI, and utilities
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        apt-transport-https \
        software-properties-common \
        git \
        curl \
        unzip \
        ca-certificates \
        less \
        docker.io \
    && wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    # Installing powershell triggers dbus which fails in containers (expected). Use semicolons to continue past the trigger error.
    && apt-get install -y --no-install-recommends powershell; \
    dpkg --configure -a || true; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -f /usr/sbin/policy-rc.d

WORKDIR /workspaces/labview-icon-editor-sandbox
