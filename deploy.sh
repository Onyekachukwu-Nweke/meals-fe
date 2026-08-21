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
: > .env
written=0
for k in ${MOUNTABO_ENV_KEYS:-}; do
  v="${!k-}"
  if [ -z "$v" ]; then
    echo "warning: env var $k is empty (set it in the secrets tab, then redeploy)"
    continue
  fi
  printf '%s=%s\n' "$k" "$v" >> .env
  written=$((written + 1))
done
echo "wrote $written environment variable(s) to .env"
if [ -n "${MOUNTABO_ENV_KEYS:-}" ] && [ "$written" -eq 0 ]; then
  echo "error: environment variables were configured but none reached .env" >&2
  exit 1
fi

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

# Mount the operator's .env into every compose service as container environment
# (compose otherwise uses .env only for interpolation, not as container env).
COMPOSE=""
for cf in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$cf" ]; then COMPOSE="$cf"; break; fi
done
COMPOSE_ARGS=""
if [ -n "$COMPOSE" ]; then
  COMPOSE_ARGS="-f $COMPOSE"
  for ov in docker-compose.override.yml docker-compose.override.yaml compose.override.yml compose.override.yaml; do
    if [ -f "$ov" ]; then COMPOSE_ARGS="$COMPOSE_ARGS -f $ov"; break; fi
  done
  services=$(docker compose $COMPOSE_ARGS config --services 2>/dev/null || true)
  if [ -n "$services" ]; then
    {
      echo "services:"
      for s in $services; do
        printf '  %s:\n    env_file:\n      - .env\n' "$s"
      done
    } > mountabo.env.override.yml
    COMPOSE_ARGS="$COMPOSE_ARGS -f mountabo.env.override.yml"
    echo "mounting .env into services: $services"
  fi
fi

# Pin build-services to the runner-built images (loaded above); merged last so
# its image: wins and the server never rebuilds.
if [ -f "/tmp/meals-fe-deploy/mountabo.image.override.yml" ]; then
  cp "/tmp/meals-fe-deploy/mountabo.image.override.yml" ./mountabo.image.override.yml
  COMPOSE_ARGS="$COMPOSE_ARGS -f mountabo.image.override.yml"
fi

TARBALL="/tmp/meals-fe-deploy/image.tar.zst"
trap 'rm -f "$TARBALL"' EXIT
echo "Loading image from $TARBALL..."
loaded=""
if [ -f "$TARBALL" ]; then
  loaded=$(zstd -dc "$TARBALL" | docker load | sed -n 's/^Loaded image: //p') || {
    echo "error: image load failed (corrupt or incomplete transfer?)" >&2
    exit 1
  }
  echo "loaded image(s): $loaded"
else
  echo "no image tarball shipped; images will be pulled on the server"
fi

echo "Swapping to new containers (built on the runner, no build here)..."
docker compose $COMPOSE_ARGS up -d --no-build --force-recreate --remove-orphans

docker compose $COMPOSE_ARGS ps

# Bound disk: drop older mountabo image tags for this app, keeping the loaded one(s).
if [ -n "$loaded" ]; then
  docker images --filter=reference="mountabo/meals-fe-*:*" --format '{{.Repository}}:{{.Tag}}' \
    | grep -vxF -f <(printf '%s\n' "$loaded") \
    | xargs -r docker rmi -f 2>/dev/null || true
fi
echo "=== Deployment complete ==="
