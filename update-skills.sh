#!/usr/bin/env bash
# update-skills.sh — atualiza skills/configs locais com a última versão do repo
# Uso: curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/update-skills.sh | bash
# (ou roda direto se já tiver baixado: ./update-skills.sh)

set -e

BASE_URL="https://raw.githubusercontent.com/nandovitor/OpenCode/master"

# Cores
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; N='\033[0m'
ok()   { echo -e "${G}✓ $*${N}"; }
info() { echo -e "${B}ℹ $*${N}"; }
warn() { echo -e "${Y}⚠ $*${N}"; }
err()  { echo -e "${R}✗ $*${N}" >&2; }

# Lista canônica de skills publicadas no repo
# Adicione novas skills aqui conforme forem criadas
SKILLS=(
  "sicc-cadastros"
)

echo ""
info "Atualizando skills do repo nandovitor/OpenCode..."
echo ""

UPDATED=0
FAILED=0
for skill in "${SKILLS[@]}"; do
  DEST="$HOME/.claude/skills/$skill"
  URL="$BASE_URL/skills/$skill/SKILL.md?_=$(date +%s)"

  mkdir -p "$DEST"
  TMPFILE=$(mktemp)
  if curl -fsSL "$URL" -o "$TMPFILE" 2>/dev/null; then
    SIZE=$(wc -c < "$TMPFILE")
    if [ "$SIZE" -lt 500 ]; then
      warn "$skill: arquivo suspeitamente pequeno ($SIZE bytes) — pulado"
      rm -f "$TMPFILE"
      FAILED=$((FAILED + 1))
      continue
    fi
    if [ -f "$DEST/SKILL.md" ] && cmp -s "$TMPFILE" "$DEST/SKILL.md"; then
      info "$skill: já estava atualizada ($SIZE bytes)"
    else
      mv "$TMPFILE" "$DEST/SKILL.md"
      ok "$skill: atualizada ($SIZE bytes) em $DEST/SKILL.md"
      UPDATED=$((UPDATED + 1))
    fi
  else
    err "$skill: falha ao baixar de $URL"
    rm -f "$TMPFILE"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
if [ "$FAILED" -gt 0 ]; then
  warn "Concluído com $FAILED falhas. Verifica internet e tenta de novo."
  exit 1
fi
if [ "$UPDATED" -eq 0 ]; then
  ok "Tudo já estava na versão mais recente."
else
  ok "$UPDATED skill(s) atualizada(s)."
  echo ""
  info "Pra usar a versão nova, é só reiniciar o OpenCode (ou abrir nova sessão do Claude Code)."
fi
echo ""
