#!/usr/bin/env bash

set -Eeuo pipefail

LOG_FILE="/var/log/docker-install.log"
MIRROR_1="https://docker.arvancloud.ir"
MIRROR_2="https://mirror.focker.ir"
DAEMON_FILE="/etc/docker/daemon.json"

exec > >(tee -a "${LOG_FILE}") 2>&1
trap 'echo "[ERROR] Script failed at line $LINENO"; exit 1' ERR

echo "===== Docker Installation Started ====="
echo "Date: $(date)"

# ---- Root Check ----
if [[ $EUID -ne 0 ]]; then
   echo "Please run as root (use sudo)."
   exit 1
fi

# ---- Check Ubuntu ----
if ! grep -qi ubuntu /etc/os-release; then
    echo "This script only supports Ubuntu."
    exit 1
fi

# ---- Install dependencies ----
echo "[INFO] Installing dependencies..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release jq

# ---- Add Docker GPG Key ----
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    echo "[INFO] Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
fi

# ---- Add Docker Repository ----
if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
    echo "[INFO] Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) \
      signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list
fi

# ---- Remove Old Docker Versions (docker.io etc.) ----
echo "[INFO] Checking for old Docker packages..."

if dpkg -l | grep -qE 'docker.io|docker-doc|docker-compose|podman-docker|containerd|runc'; then
    echo "[INFO] Removing old Docker-related packages..."
    systemctl stop docker 2>/dev/null || true
    apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc || true
fi

# ---- Install Docker CE ----
echo "[INFO] Installing Docker CE..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---- Configure Registry Mirrors ----
echo "[INFO] Configuring Docker registry mirrors..."
mkdir -p /etc/docker

if [[ -f "$DAEMON_FILE" ]]; then
    echo "[INFO] Existing daemon.json found. Merging mirrors..."
    tmp=$(mktemp)

    jq --arg m1 "$MIRROR_1" \
       --arg m2 "$MIRROR_2" \
       '
       .["registry-mirrors"] =
       ((.["registry-mirrors"] // []) + [$m1, $m2] | unique)
       ' "$DAEMON_FILE" > "$tmp"

    mv "$tmp" "$DAEMON_FILE"
else
    cat > "$DAEMON_FILE" <<EOF
{
  "registry-mirrors": [
    "$MIRROR_1",
    "$MIRROR_2"
  ]
}
EOF
fi

# ---- Enable & Restart Docker ----
echo "[INFO] Enabling and restarting Docker..."
systemctl enable docker
systemctl restart docker

# ---- Add invoking user to docker group ----
if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER" || true
    echo "[INFO] Added $SUDO_USER to docker group (logout required)."
fi

# ---- Verification ----
echo "[INFO] Verifying installation..."
docker --version
docker info | grep -A 5 "Registry Mirrors" || true

echo "===== Docker Installation Completed Successfully ====="
