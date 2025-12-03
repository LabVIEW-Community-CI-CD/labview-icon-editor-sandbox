FROM mcr.microsoft.com/dotnet/sdk:8.0

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
    && apt-get install -y --no-install-recommends powershell \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspaces/labview-icon-editor-sandbox
