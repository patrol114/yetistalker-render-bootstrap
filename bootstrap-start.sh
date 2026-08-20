#!/usr/bin/env bash
set -euo pipefail

readonly APP_DIR="${YETI_APP_DIR:-private-src}"
test -f "$APP_DIR/yetistalker/deploy/start-render.sh" || {
  printf 'BŁĄD: brak zbudowanego YetiStalker w %s\n' "$APP_DIR" >&2
  exit 1
}

exec bash "$APP_DIR/yetistalker/deploy/start-render.sh"

