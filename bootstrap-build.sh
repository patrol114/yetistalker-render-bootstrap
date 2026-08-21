#!/usr/bin/env bash
# Pobiera prywatny YetiStalker kluczem deploy-only i buduje go na Renderze.
set -euo pipefail

readonly APP_DIR="${YETI_APP_DIR:-private-src}"
readonly REPO_SSH="${YETI_REPO_SSH:-git@github.com:patrol114/yetistalker.git}"
readonly COMMIT="${YETI_GITHUB_COMMIT:?Brak YETI_GITHUB_COMMIT}"
readonly KEY_B64="${YETI_GITHUB_DEPLOY_KEY_B64:?Brak YETI_GITHUB_DEPLOY_KEY_B64}"
readonly EXPECTED_GITHUB_ED25519="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"

# Manifest jest kontrolą spójności wydania, a nie źródłem sekretów.  Nie
# zastępujemy nim YETI_GITHUB_COMMIT, ponieważ immutable pin musi być jawnie
# ustawiony w Render.  Odmawiamy jednak budowy, gdy manifest i env wskazują
# różne wersje — inaczej bootstrap może po cichu uruchomić stary kod.
if [[ -f release-manifest.json ]]; then
  manifest_commit="$(python3 - <<'PY'
import json
from pathlib import Path

try:
    value = json.loads(Path("release-manifest.json").read_text())
except Exception:
    raise SystemExit(2)

commit = value.get("application_commit", "")
print(commit if isinstance(commit, str) else "")
PY
  )" || {
    printf '%s\n' 'BŁĄD: nie można odczytać application_commit z release-manifest.json.' >&2
    exit 1
  }
  if [[ -n "$manifest_commit" && "$manifest_commit" != "$COMMIT" ]]; then
    printf 'BŁĄD: YETI_GITHUB_COMMIT nie zgadza się z release-manifest.json (%s != %s).\n' \
      "$COMMIT" "$manifest_commit" >&2
    exit 1
  fi
fi

tmp_dir="$(mktemp -d)"
key_file="$tmp_dir/deploy_key"
known_hosts="$tmp_dir/known_hosts"

cleanup() {
  rm -f "$key_file" "$known_hosts"
  rmdir "$tmp_dir" 2>/dev/null || true
}
trap cleanup EXIT

umask 077
printf '%s' "$KEY_B64" | base64 --decode >"$key_file"
chmod 600 "$key_file"

# Weryfikacja oficjalnego odcisku GitHub chroni pobranie przed podszyciem się hosta.
ssh-keyscan -t ed25519 github.com 2>/dev/null >"$known_hosts"
actual_fingerprint="$(ssh-keygen -lf "$known_hosts" -E sha256 | awk 'NR == 1 {print $2}')"
if [[ "$actual_fingerprint" != "$EXPECTED_GITHUB_ED25519" ]]; then
  printf 'BŁĄD: niezgodny odcisk SSH GitHub: %s\n' "$actual_fingerprint" >&2
  exit 1
fi

rm -rf -- "$APP_DIR"
export GIT_SSH_COMMAND="ssh -i $key_file -o IdentitiesOnly=yes -o UserKnownHostsFile=$known_hosts -o StrictHostKeyChecking=yes"
git clone --filter=blob:none --no-checkout "$REPO_SSH" "$APP_DIR"

git -C "$APP_DIR" checkout --detach "$COMMIT"
if [[ "$(git -C "$APP_DIR" rev-parse HEAD)" != "$COMMIT" ]]; then
  printf 'BŁĄD: pobrano inny commit niż oczekiwany.\n' >&2
  exit 1
fi
unset GIT_SSH_COMMAND

# Historia i dane uwierzytelniające nie są potrzebne w obrazie uruchomieniowym.
rm -rf -- "$APP_DIR/.git"
bash "$APP_DIR/yetistalker/deploy/install-pip-deps.sh"
