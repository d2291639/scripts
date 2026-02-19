#!/bin/bash

# GitLab CE Docker Compose Deployment Script (Full Version)
# Works with classic docker-compose or Docker Compose plugin
# Requires Docker pre-installed

set -e

# -------------------------------
# 1. Check prerequisites
# -------------------------------
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Determine which docker-compose command to use
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "Docker and Docker Compose are installed. Proceeding..."
echo "Using Compose command: $COMPOSE_CMD"

# -------------------------------
# 2. Prompt user for configuration
# -------------------------------
read -p "Enter your GitLab hostname (e.g., gitlab.example.com or local IP): " GITLAB_HOST

# Prompt for custom ports
read -p "Enter HTTP port (default 80): " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-80}

read -p "Enter HTTPS port (default 443): " HTTPS_PORT
HTTPS_PORT=${HTTPS_PORT:-443}

read -p "Enter SSH port (default 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

# Prompt for secure root password
while true; do
    read -s -p "Enter root password for GitLab: " ROOT_PASSWORD
    echo
    read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo
    if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]; then
        echo "Passwords do not match. Please try again."
    elif [ ${#ROOT_PASSWORD} -lt 8 ]; then
        echo "Password too short. Must be at least 8 characters."
    else
        break
    fi
done

echo "Configuration complete."

# -------------------------------
# 3. Prepare deployment directory
# -------------------------------
DEPLOY_DIR="$HOME/gitlab-docker"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# -------------------------------
# 4. Create Docker Compose file
# -------------------------------
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    restart: always
    hostname: $GITLAB_HOST
    environment:
      GITLAB_ROOT_PASSWORD: "$ROOT_PASSWORD"
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
      - "${SSH_PORT}:22"
    volumes:
      - gitlab-config:/etc/gitlab
      - gitlab-logs:/var/log/gitlab
      - gitlab-data:/var/opt/gitlab

volumes:
  gitlab-config:
  gitlab-logs:
  gitlab-data:
EOF

echo "docker-compose.yml created at $DEPLOY_DIR."

# -------------------------------
# 5. Check if container exists
# -------------------------------
if docker ps -a --format '{{.Names}}' | grep -Eq "^gitlab\$"; then
    echo "Error: A Docker container named 'gitlab' already exists. Please remove it first."
    exit 1
fi

# -------------------------------
# 6. Launch GitLab
# -------------------------------
echo "Starting GitLab CE container via Docker Compose..."
$COMPOSE_CMD up -d

echo "GitLab CE Docker Compose deployment complete!"
echo "Access GitLab at: http://$GITLAB_HOST:$HTTP_PORT (or https://$GITLAB_HOST:$HTTPS_PORT if SSL is configured)"
echo "SSH access on port: $SSH_PORT"
echo "Default root user: 'root' with the password you set."
