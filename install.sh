#!/usr/bin/env bash
# Gelato Student — учебный режим для OpenCode, Claude Code и Codex (macOS / Linux).
#
#   curl -fsSL https://raw.githubusercontent.com/bubli-mubli/gelato-student/main/install.sh | bash
#   ./install.sh                 из скачанной папки
#   ./install.sh --default       ещё и включить режим по умолчанию (OpenCode и Claude Code)
#   ./install.sh --only claude   только Claude Code (или --only opencode, --only codex)
#   ./install.sh --uninstall     удалить всё, что поставил установщик, и вернуть бэкапы
#
# Нужны bash и curl (или git-клон). sudo не нужен.

set -euo pipefail

SLUG="${GELATO_REPO:-bubli-mubli/gelato-student}"
BRANCH="${GELATO_BRANCH:-main}"
SKILLS=(gelato-hints gelato-review gelato-debug gelato-explain gelato-teach-back gelato-practice gelato-progress)
HOME_DIR="$HOME/.gelato-student"
MANIFEST="$HOME_DIR/manifest.tsv"
OC_DIR="${OPENCODE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
CC_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CX_DIR="${CODEX_HOME:-$HOME/.codex}"
AG_DIR="$HOME/.agents/skills"

ONLY=""
SET_DEFAULT=0
UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift ;;
    --default) SET_DEFAULT=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h | --help) sed -n '2,10p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "Неизвестный флаг: $1" >&2; exit 2 ;;
  esac
  shift
done

ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

# ── удаление ────────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = 1 ]; then
  [ -f "$MANIFEST" ] || die "Gelato Student не установлен (нет $MANIFEST)"
  while IFS=$'\t' read -r dest backup; do
    [ -n "$dest" ] || continue
    rm -rf "$dest"
    if [ -n "$backup" ] && [ -e "$backup" ]; then mv "$backup" "$dest"; info "вернул $dest из бэкапа"; fi
  done <"$MANIFEST"
  for f in "$OC_DIR/opencode.json" "$CC_DIR/settings.json" "$CX_DIR/AGENTS.md"; do
    [ -f "$f.gelato.bak" ] && mv "$f.gelato.bak" "$f" && info "вернул $f"
    [ -f "$f.gelato.new" ] && rm -f "$f" "$f.gelato.new" && info "удалил $f"
  done
  rm -rf "$HOME_DIR"
  ok "Gelato Student удалён"
  exit 0
fi

# ── исходники набора: из папки рядом со скриптом или скачать архив ─────────
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  [ -d "$here/skills/gelato-hints" ] && SRC="$here"
fi
TMP=""
if [ -z "$SRC" ]; then
  command -v curl >/dev/null || die "Нужен curl"
  TMP="$(mktemp -d)"
  trap '[ -n "$TMP" ] && rm -rf "$TMP"' EXIT
  echo "Скачиваю набор с github.com/$SLUG…"
  curl -fsSL "https://codeload.github.com/$SLUG/tar.gz/refs/heads/$BRANCH" | tar -xz -C "$TMP" \
    || die "Не удалось скачать github.com/$SLUG"
  SRC="$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -n 1)"
fi
[ -d "$SRC/skills/gelato-hints" ] || die "В $SRC нет набора"

# ── куда ставить ────────────────────────────────────────────────────────────
WANT_OC=1
WANT_CC=1
WANT_CX=1
case "$ONLY" in
  "") ;;
  opencode) WANT_CC=0; WANT_CX=0 ;;
  claude) WANT_OC=0; WANT_CX=0 ;;
  codex) WANT_OC=0; WANT_CC=0 ;;
  *) die "--only: opencode, claude или codex" ;;
esac
HAS_OC=0; { command -v opencode >/dev/null || [ -d "$OC_DIR" ]; } && HAS_OC=1
HAS_CC=0; { command -v claude >/dev/null || [ -d "$CC_DIR" ]; } && HAS_CC=1
HAS_CX=0; { command -v codex >/dev/null || [ -d "$CX_DIR" ]; } && HAS_CX=1
if [ -z "$ONLY" ] && [ "$HAS_OC" = 0 ] && [ "$HAS_CC" = 0 ] && [ "$HAS_CX" = 0 ]; then
  warn "Не нашёл ни OpenCode, ни Claude Code, ни Codex — ставлю для всех, заработает после установки любого."
elif [ -z "$ONLY" ]; then
  [ "$HAS_OC" = 1 ] || WANT_OC=0
  [ "$HAS_CC" = 1 ] || WANT_CC=0
  [ "$HAS_CX" = 1 ] || WANT_CX=0
fi

mkdir -p "$HOME_DIR"
: >>"$MANIFEST"

# Копия с бэкапом чужого файла; запоминаем в манифесте, чтобы потом удалить
put() {
  local src="$1" dest="$2" backup=""
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && ! grep -q "^$dest	" "$MANIFEST"; then
    backup="$dest.gelato.bak"
    rm -rf "$backup"
    mv "$dest" "$backup"
  fi
  rm -rf "$dest"
  cp -R "$src" "$dest"
  grep -q "^$dest	" "$MANIFEST" || printf '%s\t%s\n' "$dest" "$backup" >>"$MANIFEST"
}

# Прописать ключ в JSON-конфиг (нужен python3); бэкап — рядом
set_json() {
  local file="$1" key="$2" value="$3"
  command -v python3 >/dev/null || { warn "нет python3 — пропишите \"$key\": \"$value\" в $file вручную"; return; }
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ]; then
    [ -f "$file.gelato.bak" ] || [ -f "$file.gelato.new" ] || cp "$file" "$file.gelato.bak"
  else
    : >"$file.gelato.new"
  fi
  python3 - "$file" "$key" "$value" <<'PY'
import json, os, sys
f, k, v = sys.argv[1:]
d = json.load(open(f)) if os.path.exists(f) and os.path.getsize(f) else {}
d[k] = v
json.dump(d, open(f, "w"), ensure_ascii=False, indent=2)
PY
}

if [ "$WANT_OC" = 1 ]; then
  ver=2
  if command -v opencode >/dev/null; then
    major="$(opencode --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+' | head -n 1 || true)"
    [ "${major:-}" = 0 ] || [ "${major:-}" = 1 ] && ver=1
  fi
  agent="$SRC/agents/opencode/gelato-student.md"
  [ "$ver" = 1 ] && agent="$SRC/agents/opencode-v1/gelato-student.md"
  put "$agent" "$OC_DIR/agents/gelato-student.md"
  for s in "${SKILLS[@]}"; do put "$SRC/skills/$s" "$OC_DIR/skills/$s"; done
  [ "$SET_DEFAULT" = 1 ] && set_json "$OC_DIR/opencode.json" default_agent gelato-student
  ok "OpenCode (формат V$ver): агент gelato-student и ${#SKILLS[@]} скиллов → $OC_DIR"
fi

if [ "$WANT_CC" = 1 ]; then
  put "$SRC/claude/gelato-student.md" "$CC_DIR/output-styles/gelato-student.md"
  for s in "${SKILLS[@]}"; do put "$SRC/skills/$s" "$CC_DIR/skills/$s"; done
  [ "$SET_DEFAULT" = 1 ] && set_json "$CC_DIR/settings.json" outputStyle "Gelato Student"
  ok "Claude Code: режим «Gelato Student» и ${#SKILLS[@]} скиллов → $CC_DIR"
fi

if [ "$WANT_CX" = 1 ]; then
  put "$SRC/codex/gelato-student" "$AG_DIR/gelato-student"
  for s in "${SKILLS[@]}"; do put "$SRC/skills/$s" "$AG_DIR/$s"; done
  if [ "$SET_DEFAULT" = 1 ]; then
    f="$CX_DIR/AGENTS.md"
    mkdir -p "$CX_DIR"
    if [ -f "$f" ]; then
      [ -f "$f.gelato.bak" ] || [ -f "$f.gelato.new" ] || cp "$f" "$f.gelato.bak"
    else
      : >"$f.gelato.new"
    fi
    grep -q "gelato-student:begin" "$f" 2>/dev/null || printf '\n<!-- gelato-student:begin -->\nВсегда работай в учебном режиме: загрузи скилл gelato-student из ~/.agents/skills и следуй ему.\n<!-- gelato-student:end -->\n' >>"$f"
  fi
  ok "Codex: режим \$gelato-student и ${#SKILLS[@]} скиллов → $AG_DIR"
fi

echo
echo "Дальше:"
if [ "$WANT_OC" = 1 ]; then
  info "OpenCode — открой папку проекта, запусти opencode и нажми Shift+Tab (в старых версиях Tab), пока не появится gelato-student."
  info "Если OpenCode уже был запущен — перезапусти его (в V2: opencode service restart), иначе он не увидит новый режим."
fi
if [ "$WANT_CC" = 1 ]; then
  info "Claude Code — запусти claude в папке проекта, затем /config → Output style → Gelato Student."
fi
if [ "$WANT_CX" = 1 ]; then
  info "Codex — запусти codex в папке проекта и напиши \$gelato-student (перезапусти Codex, если он был открыт)."
fi
[ "$SET_DEFAULT" = 1 ] && info "Режим уже включён по умолчанию."
info "Напиши «застрял» — и получишь первую подсказку, а не готовый код."
info "Удалить: curl -fsSL https://raw.githubusercontent.com/$SLUG/$BRANCH/install.sh | bash -s -- --uninstall"
