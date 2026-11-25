#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-main}"
DEPLOYMENT_ID="mtb-8d946244dfa2"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/meals-fe}/$DEPLOYMENT_ID"

echo "=== meals-fe deploy (branch: $BRANCH) ==="

# --- mountabo: serialize on the server, and refuse superseded work ------------
MOUNTABO_STATE="${MOUNTABO_STATE:-$HOME/.mountabo}"
MOUNTABO_MODE="${MOUNTABO_MODE:-deploy}"
STATE_FILE="$MOUNTABO_STATE/state/$DEPLOYMENT_ID.json"
LOCK_FILE="$MOUNTABO_STATE/locks/$DEPLOYMENT_ID.lock"
EXPECT_INCARNATION=1

umask 077
mkdir -p "$MOUNTABO_STATE/state" "$MOUNTABO_STATE/locks" "$MOUNTABO_STATE/releases"
chmod 700 "$MOUNTABO_STATE" 2>/dev/null || true

if ! command -v flock >/dev/null 2>&1; then
  echo "error: flock is missing on this server, so mountabo cannot serialize this deploy" >&2
  echo "       install it (apt-get install -y util-linux) and re-run setup for this server" >&2
  exit 1
fi
exec 9>"$LOCK_FILE"
if ! flock -w "${MOUNTABO_LOCK_WAIT:-900}" 9; then
  echo "error: another operation on this deployment holds the lock; it did not finish in time" >&2
  exit 1
fi

# Everything below runs under the lock, so the state read cannot race a teardown.
if [ -f "$STATE_FILE" ]; then
  state_lifecycle="$(jq -r '.lifecycle // "active"' "$STATE_FILE" 2>/dev/null || echo active)"
  state_incarnation="$(jq -r '.incarnation // 1' "$STATE_FILE" 2>/dev/null || echo 1)"
  case "$state_lifecycle" in
    deleting|deleted)
      echo "This deployment was deleted in mountabo, so this run will not deploy."
      echo "Recreate it from mountabo if you want it back; that resets its state deliberately."
      exit 0
      ;;
    blocked)
      echo "error: this deployment is blocked on an unresolved migration outcome." >&2
      echo "       Resolve it in mountabo (confirm whether the migration applied) before deploying." >&2
      exit 1
      ;;
  esac
  if [ "$state_incarnation" -gt "$EXPECT_INCARNATION" ] 2>/dev/null; then
    echo "This run was generated for an earlier incarnation of this deployment (#$EXPECT_INCARNATION,"
    echo "now #$state_incarnation), so it has been superseded and will not deploy."
    exit 0
  fi
fi
MOUNTABO_KIND="${MOUNTABO_KIND:-deploy}"

# --- mountabo: this operation's identity --------------------------------------
# The artifact names one BUILD, not one commit: the same commit rebuilt with
# different build arguments or a moved base image is a different image, so a
# commit-keyed name would be overwritten in place and the artifact that had been
# running would stop being recoverable.
#
# A rollback names an artifact that already exists rather than minting one. It is
# the same script either way — one code path, so a rollback can never diverge
# from the deploy it is undoing — with only its inputs switched.
REL_ROOT="$MOUNTABO_STATE/releases/$DEPLOYMENT_ID"
if [ "$MOUNTABO_MODE" = rollback ]; then
  ARTIFACT_ID="${MOUNTABO_ARTIFACT:?MOUNTABO_ARTIFACT must name a retained release}"
  BUNDLE="$REL_ROOT/$ARTIFACT_ID"
  if [ ! -d "$BUNDLE" ]; then
    echo "error: release $ARTIFACT_ID is no longer retained on this server" >&2
    echo "       mountabo keeps the active release and the one before it; pick a newer release" >&2
    exit 1
  fi
  echo "=== rolling back to $ARTIFACT_ID (no rebuild) ==="
else
  ARTIFACT_ID="${MOUNTABO_ARTIFACT_ID:?MOUNTABO_ARTIFACT_ID must be set by the workflow}"
  BUNDLE="$REL_ROOT/$ARTIFACT_ID"
fi
OPERATION_ID="${MOUNTABO_OPERATION_ID:-}"

sudo mkdir -p "$DEPLOY_DIR"
sudo chown -R "$(id -un):$(id -gn)" "$(dirname "$DEPLOY_DIR")"
cd "$DEPLOY_DIR"
if [ -d .git ]; then
  echo "removing the old source checkout (mountabo no longer copies your repository to the server)"
  if command -v git >/dev/null 2>&1; then
    git ls-files -z | xargs -0 -r rm -f --
  fi
  rm -rf .git
fi
if [ -f "$HOME/.ssh/mountabo_deploy_Onyekachukwu-Nweke_meals-fe" ]; then
  echo "removing the old repository deploy key from this server (no longer needed)"
  rm -f "$HOME/.ssh/mountabo_deploy_Onyekachukwu-Nweke_meals-fe" "$HOME/.ssh/mountabo_deploy_Onyekachukwu-Nweke_meals-fe.pub"
fi
COMPOSE_TAR="/tmp/mtb-8d946244dfa2-deploy/mountabo.compose.tar.gz"
if [ "$MOUNTABO_MODE" = rollback ]; then
  COMPOSE_TAR="$BUNDLE/compose.tar.gz"
fi
if [ -f "$COMPOSE_TAR" ]; then
  tar -xzf "$COMPOSE_TAR" -C "$DEPLOY_DIR"
  echo "compose files in place: $(tar -tzf "$COMPOSE_TAR" | grep -v '/$' | tr '\n' ' ')"
  if [ "$MOUNTABO_MODE" = deploy ]; then
    mkdir -p "$BUNDLE"
    cp "$COMPOSE_TAR" "$BUNDLE/compose.tar.gz"
    rm -f "/tmp/mtb-8d946244dfa2-deploy/mountabo.compose.tar.gz"
  fi
elif [ "$MOUNTABO_MODE" = deploy ]; then
  echo "error: the compose files were not shipped with this build (mountabo.compose.tar.gz is missing)" >&2
  exit 1
else
  echo "note: this release predates shipped compose files; using the ones already here"
fi
cd "$DEPLOY_DIR"
export COMPOSE_PROJECT_NAME="mtb-8d946244dfa2"

if [ "$MOUNTABO_MODE" = deploy ]; then
# Write .env (ports + your environment variables) for docker compose.
: > .env
mountabo_env_line() {
  local v="$2"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//\$/\\\$}"
  v="${v//$'\n'/\\n}"
  v="${v//$'\r'/\\r}"
  printf '%s="%s"\n' "$1" "$v"
}
written=0
for k in ${MOUNTABO_ENV_KEYS:-}; do
  # Test whether the variable is SET, not whether it is non-empty. A variable an
  # operator deliberately set to "" is a configured value: dropping it made the
  # application see an unset variable instead of an empty one, which for most
  # runtimes is a different thing entirely (undefined vs ""). Only a name that
  # never arrived — not configured on the GitHub environment, or not forwarded —
  # is skipped.
  if [ -z "${!k+x}" ]; then
    echo "warning: env var $k is not set on this GitHub environment (add it in the secrets tab, then redeploy)"
    continue
  fi
  mountabo_env_line "$k" "${!k}" >> .env
  written=$((written + 1))
done
echo "wrote $written environment variable(s) to .env"
if [ -n "${MOUNTABO_ENV_KEYS:-}" ] && [ "$written" -eq 0 ]; then
  echo "error: environment variables were configured but none reached .env" >&2
  exit 1
fi
fi

# Regenerate any per-service env files the compose references (env_file:) from
# the .env above, so a changed secret reaches every service and not just the root.
mountabo_write_service_env() {
  ef="$1"
  if [ "$(readlink -f "$ef" 2>/dev/null || echo "$ef")" = "$(readlink -f .env)" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$ef")"
  if git ls-files --error-unmatch -- "$ef" >/dev/null 2>&1; then
    git checkout -- "$ef"
    if [ -s "$ef" ] && [ "$(tail -c1 "$ef" | wc -l)" -eq 0 ]; then
      printf '\n' >> "$ef"
    fi
    cat .env >> "$ef"
    echo "refreshed $ef (committed defaults + your configured values)"
  else
    cp .env "$ef"
    echo "refreshed $ef"
  fi
}

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
    *.env) mountabo_write_service_env "$ef" ;;
  esac
done

# Mount the operator's .env into every compose service as container environment
# (compose otherwise uses .env only for interpolation, not as container env), and
# stamp this deployment's ownership labels so teardown can select them.
MOUNTABO_LABELS="mountabo.deployment=mtb-8d946244dfa2 mountabo.owner=onyekachukwu-nweke mountabo.repo=meals-fe mountabo.environment=production mountabo.artifact=$ARTIFACT_ID"
COMPOSE=""
for cf in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
  if [ -f "$cf" ]; then COMPOSE="$cf"; break; fi
done
if [ -z "$COMPOSE" ]; then
  echo "error: no compose file found (looked for: docker-compose.yml, docker-compose.yaml, compose.yml, compose.yaml)" >&2
  echo "       set the compose file for this environment in mountabo if yours is named differently" >&2
  exit 1
fi

COMPOSE_ARGS="-f $COMPOSE"
for ov in docker-compose.override.yml docker-compose.override.yaml compose.override.yml compose.override.yaml; do
  if [ -f "$ov" ]; then COMPOSE_ARGS="$COMPOSE_ARGS -f $ov"; break; fi
done

# Enumerate services, keeping the error if it fails. A stack whose services
# cannot be listed cannot have configuration injected into it, and shipping that
# silently is exactly what this replaces.
compose_err="$(mktemp)"
services="$(docker compose $COMPOSE_ARGS config --no-interpolate --format json 2>"$compose_err" | jq -r '.services | keys[]' 2>/dev/null || true)"
if [ -z "$services" ]; then
  # Older compose plugins have no --format; fall back before treating it as fatal.
  services="$(docker compose $COMPOSE_ARGS config --services 2>>"$compose_err" || true)"
fi
if [ -z "$services" ]; then
  echo "error: could not read the services from $COMPOSE, so no environment variables can be injected." >&2
  echo "       docker compose reported:" >&2
  sed 's/^/       /' "$compose_err" >&2 || true
  rm -f "$compose_err"
  exit 1
fi
rm -f "$compose_err"

{
  echo "services:"
  for s in $services; do
    printf '  %s:\n    env_file:\n      - .env\n    labels:\n' "$s"
    for l in $MOUNTABO_LABELS; do printf '      - %s\n' "$l"; done
  done
} > mountabo.env.override.yml
COMPOSE_ARGS="$COMPOSE_ARGS -f mountabo.env.override.yml"
echo "mounting .env into services: $(echo $services | tr '\n' ' ')"

# Pin build-services to exact images; merged last so its image: wins and the
# server never rebuilds. On a deploy the pins come from the runner (shipped
# beside the tarball); on a rollback they come from the target release's own
# bundle, which is what makes the rollback re-point rather than rebuild.
if [ "$MOUNTABO_MODE" = rollback ]; then
  if [ ! -f "$BUNDLE/image.override.yml" ]; then
    echo "error: release $ARTIFACT_ID has no image pins recorded, so it cannot be rolled back to" >&2
    exit 1
  fi
  cp "$BUNDLE/image.override.yml" ./mountabo.image.override.yml
  COMPOSE_ARGS="$COMPOSE_ARGS -f mountabo.image.override.yml"
elif [ -f "/tmp/mtb-8d946244dfa2-deploy/mountabo.image.override.yml" ]; then
  cp "/tmp/mtb-8d946244dfa2-deploy/mountabo.image.override.yml" ./mountabo.image.override.yml
  COMPOSE_ARGS="$COMPOSE_ARGS -f mountabo.image.override.yml"
fi

TARBALL="/tmp/mtb-8d946244dfa2-deploy/image.tar.zst"
trap 'rm -f "$TARBALL"' EXIT
loaded=""
# A rollback re-points to images already in the local store — there is no
# tarball, and re-loading one would defeat the point of not rebuilding.
if [ "$MOUNTABO_MODE" = deploy ]; then
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
else
  loaded="$(jq -r '.images[]?.ref // empty' "$BUNDLE/manifest.json" 2>/dev/null | tr '\n' ' ')"
  echo "re-pointing to retained image(s): $loaded"
fi

# --- mountabo: release state --------------------------------------------------
mountabo_state_read() {
  if [ -f "$STATE_FILE" ]; then cat "$STATE_FILE"; else echo '{}'; fi
}

# mountabo_state_get FILTER -> the value, or "" when absent.
mountabo_state_get() {
  mountabo_state_read | jq -r "$1 // empty" 2>/dev/null || true
}

# mountabo_state_write FILTER [--arg k v ...]
# Writes the whole document via a temp file + rename, which is atomic within a
# filesystem: a crash cannot leave a half-written state document behind.
mountabo_state_write() {
  __filter="$1"; shift
  __tmp="$STATE_FILE.tmp.$$"
  if mountabo_state_read | jq -c \
      --arg __now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg __did "$DEPLOYMENT_ID" \
      "$@" \
      "$__filter | .deployment_id = \$__did | .updated_at = \$__now | .generation = ((.generation // 0) + 1)" \
      > "$__tmp"; then
    mv -f "$__tmp" "$STATE_FILE"
  else
    rm -f "$__tmp"
    echo "warning: could not update deployment state" >&2
  fi
}

MOUNTABO_STRATEGY='compose'
ENVIRONMENT='production'
MOUNTABO_HOOKS_VERSION='e3b0c44298fc1c14'
MOUNTABO_PENDING=""

# --- mountabo: record this build before touching anything running -------------
# Skipped on rollback: that artifact's bundle was written when it was built, and
# rewriting it would overwrite the record of what it actually is.
if [ "$MOUNTABO_MODE" = deploy ]; then
mkdir -p "$BUNDLE"

# The images this release actually runs, by immutable id as well as by tag: a tag
# can be moved, an image id cannot, so the id is what proves a rollback started
# the same bytes that were running before.
mountabo_image_rows() {
  for ref in ${loaded:-}; do
    id="$(docker image inspect --format '{{.Id}}' "$ref" 2>/dev/null || echo "")"
    jq -n --arg ref "$ref" --arg id "$id" '{ref: $ref, id: $id}'
  done | jq -s '.'
}

jq -n \
  --argjson fv 1 \
  --arg artifact "$ARTIFACT_ID" \
  --arg operation "$OPERATION_ID" \
  --arg commit "${MOUNTABO_COMMIT:-unknown}" \
  --arg strategy "compose" \
  --arg deployment "$DEPLOYMENT_ID" \
  --arg dir "$PWD" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson images "$(mountabo_image_rows)" \
  '{format_version: $fv, artifact_id: $artifact, operation_id: $operation,
    commit: $commit, strategy: $strategy, deployment_id: $deployment,
    working_dir: $dir, at: $at, images: $images}' > "$BUNDLE/manifest.json"

# Keep the script that produced this bundle beside it. A rollback runs this copy,
# so a bundle written by an older format is never interpreted by a newer script.
cp "$0" "$BUNDLE/runner.sh" 2>/dev/null || true
chmod 600 "$BUNDLE/manifest.json" 2>/dev/null || true
if [ -f mountabo.image.override.yml ]; then
  cp mountabo.image.override.yml "$BUNDLE/image.override.yml"
fi

echo "recorded release $ARTIFACT_ID"
fi
mountabo_state_write '.lifecycle = "deploying" | .candidate = $a | .incarnation = ($inc | tonumber)' \
  --arg a "$ARTIFACT_ID" --arg inc "$EXPECT_INCARNATION"

echo "Swapping to new containers (built on the runner, no build here)..."
# --remove-orphans on a deploy: the stack is the compose file, so a service the
# operator deleted should go. It is deliberately NOT passed on a rollback — a
# service that exists today but not in the target release would be stopped
# silently, which is a destructive surprise rather than a rollback.
if [ "$MOUNTABO_MODE" = rollback ]; then
  docker compose $COMPOSE_ARGS up -d --no-build --force-recreate
else
  docker compose $COMPOSE_ARGS up -d --no-build --force-recreate --remove-orphans
fi

docker compose $COMPOSE_ARGS ps

# Health check: confirm the app answers on its published port after the swap.
code=000
for i in 1 2 3 4 5; do
  code=$(curl -sS -k -o /dev/null --max-time 8 --connect-timeout 5 -w '%{http_code}' http://127.0.0.1:8010 2>/dev/null || echo 000)
  [ "$code" != "000" ] && break
  echo "waiting for app on :8010 (attempt $i)..."
  sleep 2
done
if [ "$code" = "000" ]; then
  echo "error: app did not respond on 127.0.0.1:8010 after deploy" >&2
  exit 1
fi
echo "app responded on :8010 (HTTP $code)"


# --- mountabo: verify what is actually serving, then commit the release -------
mountabo_running_artifacts() {
  ids="$(docker ps -q --filter "label=mountabo.deployment=$DEPLOYMENT_ID" 2>/dev/null || true)"
  [ -n "$ids" ] || return 0
  for cid in $ids; do
    docker inspect -f '{{ index .Config.Labels "mountabo.artifact" }}' "$cid" 2>/dev/null || true
  done
}

serving="$(mountabo_running_artifacts | sort -u | grep -v '^$' || true)"
if [ -z "$serving" ]; then
  echo "error: no running container carries this deployment's label; the swap did not take" >&2
  mountabo_state_write '.lifecycle = "degraded" | .running = "unknown"'
  exit 1
fi
if [ "$serving" != "$ARTIFACT_ID" ]; then
  echo "error: expected artifact $ARTIFACT_ID to be serving, but found: $serving" >&2
  echo "       the previous release may still be up; mountabo will show this as degraded" >&2
  mountabo_state_write '.lifecycle = "degraded" | .running = "unknown"'
  exit 1
fi
echo "verified: $ARTIFACT_ID is serving"

# Commit the release. A redeploy of the artifact that is already active must NOT
# move previous onto it: that would leave active and previous identical and make
# the release before it prunable, destroying the rollback target.
__prev="$(mountabo_state_get '.active')"
if [ -n "$__prev" ] && [ "$__prev" != "$ARTIFACT_ID" ]; then
  mountabo_state_write '.previous = $p | .active = $a | .candidate = null | .running = $a | .lifecycle = "active" | .kind = $k' \
    --arg p "$__prev" --arg a "$ARTIFACT_ID" --arg k "$MOUNTABO_KIND"
else
  mountabo_state_write '.active = $a | .candidate = null | .running = $a | .lifecycle = "active" | .kind = $k' \
    --arg a "$ARTIFACT_ID" --arg k "$MOUNTABO_KIND"
fi

# --- mountabo: keep the recovery points, retire the rest ----------------------
mountabo_prune_releases() {
  [ -d "$REL_ROOT" ] || return 0
  keep="$(mountabo_state_read | jq -r '[.active, .previous, .candidate] | map(select(. != null and . != "")) | .[]' 2>/dev/null || true)"
  for d in "$REL_ROOT"/*; do
    [ -d "$d" ] || continue
    a="$(basename "$d")"
    if printf '%s\n' "$keep" | grep -qxF "$a"; then continue; fi
    if [ -f "$d/manifest.json" ]; then
      jq -r '.images[]?.ref // empty' "$d/manifest.json" 2>/dev/null | while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        # Untags only. docker refuses while a container still uses the image, and
        # that refusal is correct: it is another deployment's, or still running.
        docker rmi "$ref" >/dev/null 2>&1 || true
      done
    fi
    rm -rf "$d"
    echo "retired release $a"
  done
}
mountabo_prune_releases
echo "=== Deployment complete ==="
