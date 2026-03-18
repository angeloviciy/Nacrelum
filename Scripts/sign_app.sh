#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -n "${SIGNING_ENV_FILE:-}" ]]; then
  env_file="$SIGNING_ENV_FILE"
elif [[ -f "$ROOT_DIR/.signing.env" ]]; then
  env_file="$ROOT_DIR/.signing.env"
else
  env_file="$ROOT_DIR/.env"
fi

if [[ -f "$env_file" ]]; then
  set -a
  source "$env_file"
  set +a
fi

APP_NAME="${APP_NAME:-PixelClaw}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_BUNDLE="${APP_BUNDLE:-$DIST_DIR/$APP_NAME.app}"
BUNDLE_ID="${BUNDLE_ID:-com.ronmasas.$APP_NAME}"
ENTITLEMENTS="${ENTITLEMENTS:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle at $APP_BUNDLE" >&2
  echo "Build it first with: make app" >&2
  exit 1
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(
    security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Apple Distribution:.*\)"/\1/p' \
      | head -n 1
  )"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(
    security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' \
      | head -n 1
  )"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Apple code-signing identity found." >&2
  echo "Set SIGN_IDENTITY to a certificate name from: security find-identity -v -p codesigning" >&2
  exit 1
fi

TEAM_ID="$(
  security find-certificate -c "$SIGN_IDENTITY" -p 2>/dev/null \
    | openssl x509 -noout -subject -nameopt utf8 2>/dev/null \
    | sed -nE 's/.*OU=([^,]+).*/\1/p'
)"

if [[ -z "$TEAM_ID" ]]; then
  echo "Could not determine Team ID for signing identity: $SIGN_IDENTITY" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

DESIGNATED_REQUIREMENT="designated => identifier \"$BUNDLE_ID\" and anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\""

codesign_args=(
  --force
  --sign "$SIGN_IDENTITY"
  --timestamp
  --options runtime
  "-r=$DESIGNATED_REQUIREMENT"
)

if [[ -n "$ENTITLEMENTS" ]]; then
  if [[ ! -f "$ENTITLEMENTS" ]]; then
    echo "Entitlements file not found: $ENTITLEMENTS" >&2
    exit 1
  fi
  codesign_args+=(--entitlements "$ENTITLEMENTS")
fi

codesign "${codesign_args[@]}" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Signed $APP_BUNDLE"
echo "Identity: $SIGN_IDENTITY"
echo "Bundle ID: $BUNDLE_ID"
echo "Designated requirement:"
codesign -d -r- "$APP_BUNDLE" 2>&1 | sed 's/^/  /'
