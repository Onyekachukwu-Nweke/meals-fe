#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-main}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/meals-fe}/$BRANCH"
REPO_URL="git@github.com:Onyekachukwu-Nweke/meals-fe.git"

echo "=== meals-fe deploy (branch: $BRANCH) ==="

# Use the repo's read-only deploy key for git over SSH.
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/mountabo_deploy_Onyekachukwu-Nweke_meals-fe -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

sudo mkdir -p "$DEPLOY_DIR"
sudo chown -R "$(id -un):$(id -gn)" "$(dirname "$DEPLOY_DIR")"

if [ -d "$DEPLOY_DIR/.git" ]; then
  echo "Pulling latest changes..."
  cd "$DEPLOY_DIR"
  git fetch origin
  git reset --hard "origin/$BRANCH"
else
  echo "Cloning repository..."
  rm -rf "$DEPLOY_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$DEPLOY_DIR"
  cd "$DEPLOY_DIR"
fi

export COMPOSE_PROJECT_NAME='meals-fe-main'

# Write .env (ports + your environment variables) for docker compose.
cat > .env <<EOF

EOF

# Create any per-service env files the compose references (env_file:) from the
# .env above, so the configured variables reach every service.
for cf in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  [ -f "$cf" ] || continue
  awk '
    function emit(p){ gsub(/^[ \t]+|[ \t]+$/,"",p); gsub(/^"|"$/,"",p); if(p!="") print p }
    /^[ \t]*env_file:[ \t]*[^ \t#]/ { line=$0; sub(/^[ \t]*env_file:[ \t]*/,"",line); emit(line); blk=0; next }
    /^[ \t]*env_file:[ \t]*$/ { blk=1; next }
    blk { if ($0 ~ /^[ \t]*-[ \t]*/) { line=$0; sub(/^[ \t]*-[ \t]*/,"",line); emit(line) } else if ($0 ~ /[^ \t]/) { blk=0 } }
  ' "$cf"
done | sort -u | while IFS= read -r ef; do
  case "$ef" in
    *.env) mkdir -p "$(dirname "$ef")"; [ -f "$ef" ] || cp .env "$ef" ;;
  esac
done

# Zero-downtime: build new images while old containers keep running, then swap.
echo "Building images..."
docker compose build
echo "Swapping to new containers..."
docker compose up -d --force-recreate --remove-orphans

docker compose ps
echo "=== Deployment complete ==="
