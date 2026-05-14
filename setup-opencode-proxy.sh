#!/usr/bin/env bash
# setup-opencode-proxy.sh — instala/configura o OpenCode pra usar o proxy Claude da INFOCO
# Uso: ./setup-opencode-proxy.sh <SUA_CHAVE_API>
# Suporta: Linux (Fedora/Ubuntu/Debian/Arch) e macOS

set -e

PROXY_URL="https://proxy.infocogestaopublica.com.br/v1"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"

# Cores
G='\033[0;32m'  # verde
Y='\033[1;33m'  # amarelo
R='\033[0;31m'  # vermelho
B='\033[0;34m'  # azul
N='\033[0m'     # reset

err()  { echo -e "${R}✗ $*${N}" >&2; exit 1; }
ok()   { echo -e "${G}✓ $*${N}"; }
info() { echo -e "${B}ℹ $*${N}"; }
warn() { echo -e "${Y}⚠ $*${N}"; }

# --- 1) Validar argumento ---
if [ -z "$1" ]; then
  echo "Uso: $0 <SUA_CHAVE_API>"
  echo ""
  echo "Exemplo: $0 cacaeb4f97f509e305cdbcb92126fac9479c4ea633a6a89f"
  echo ""
  echo "A chave foi enviada individualmente. Se não recebeu, pede pro Fernando."
  exit 1
fi

API_KEY="$1"

# Validação básica: hex de 48 chars
if [[ ! "$API_KEY" =~ ^[a-f0-9]{48}$ ]]; then
  warn "Chave não parece ter o formato esperado (48 hex chars). Continuando assim mesmo..."
fi

echo ""
info "Configurando OpenCode para usar o proxy CLIProxyAPI da INFOCO"
echo ""

# --- 2) Verificar OpenCode ---
if ! command -v opencode >/dev/null 2>&1; then
  warn "OpenCode não está instalado neste computador."
  echo ""
  echo "Instala primeiro com um destes comandos (escolhe um):"
  echo ""
  echo "  ${B}# Opção 1 — script oficial (mais simples)${N}"
  echo "  curl -fsSL https://opencode.ai/install | bash"
  echo ""
  echo "  ${B}# Opção 2 — via npm (precisa Node.js >=18)${N}"
  echo "  npm install -g opencode-ai"
  echo ""
  echo "Depois roda este script de novo."
  exit 1
fi
ok "OpenCode encontrado: $(command -v opencode)"

# --- 3) Testar conectividade com o proxy ---
info "Testando conexão com o proxy..."
HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
  "$PROXY_URL/models" -H "Authorization: Bearer $API_KEY" 2>/dev/null || echo "000")

case "$HTTP_CODE" in
  200) ok "Proxy respondeu HTTP 200 — chave válida e proxy online" ;;
  401) err "HTTP 401 — chave inválida. Confere se copiou direito (sem espaços, 48 caracteres)." ;;
  000) err "Não consegui alcançar o proxy. Verifica internet / DNS / firewall." ;;
  *)   err "HTTP $HTTP_CODE inesperado. Avisa o Fernando." ;;
esac

# --- 4) Backup do opencode.json se existir ---
mkdir -p "$(dirname "$OPENCODE_CONFIG")"
if [ -f "$OPENCODE_CONFIG" ]; then
  BAK="$OPENCODE_CONFIG.bak.$(date +%s)"
  cp "$OPENCODE_CONFIG" "$BAK"
  ok "Backup do config anterior: $BAK"
fi

# --- 5) Escrever opencode.json (Claude proxy + MCP infoco) ---
cat > "$OPENCODE_CONFIG" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "infoco": {
      "type": "remote",
      "url": "https://compras.app.br/mcp/documentos",
      "enabled": true
    }
  },
  "provider": {
    "cliproxy": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "CLIProxyAPI (INFOCO)",
      "options": {
        "baseURL": "https://proxy.infocogestaopublica.com.br/v1",
        "apiKey": "{env:CLIPROXY_API_KEY}"
      },
      "models": {
        "claude-opus-4-7": {
          "name": "Claude Opus 4.7",
          "limit": { "context": 200000, "output": 65536 }
        },
        "claude-sonnet-4-5-latest": {
          "name": "Claude Sonnet 4.5",
          "limit": { "context": 200000, "output": 65536 }
        },
        "claude-haiku-4-5-latest": {
          "name": "Claude Haiku 4.5 (rápido/barato)",
          "limit": { "context": 200000, "output": 32768 }
        },
        "claude-opus-4-5-latest": {
          "name": "Claude Opus 4.5",
          "limit": { "context": 200000, "output": 32768 }
        },
        "gpt-5.4": {
          "name": "GPT-5.4 (flagship OpenAI)",
          "limit": { "context": 200000, "output": 65536 }
        },
        "gpt-5.4-mini": {
          "name": "GPT-5.4 Mini (rápido/barato)",
          "limit": { "context": 200000, "output": 32768 }
        },
        "gpt-5.3-codex": {
          "name": "GPT-5.3 Codex (especializado em código)",
          "limit": { "context": 200000, "output": 65536 }
        },
        "gpt-5.5": {
          "name": "GPT-5.5 (mais novo OpenAI)",
          "limit": { "context": 200000, "output": 65536 }
        },
        "gpt-image-2": {
          "name": "GPT Image 2 (geração de imagem)"
        }
      }
    }
  }
}
EOF
ok "opencode.json escrito em: $OPENCODE_CONFIG (proxy Claude + MCP infoco)"

# --- 6) Adicionar CLIPROXY_API_KEY ao shell rc ---
# Detecta shell
SHELL_NAME=$(basename "${SHELL:-/bin/bash}")
case "$SHELL_NAME" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) RC="$HOME/.bashrc" ;;
  fish) RC="$HOME/.config/fish/config.fish" ;;
  *)    RC="$HOME/.profile" ;;
esac

# Remove linha antiga (idempotência) e adiciona nova
if [ -f "$RC" ]; then
  # backup
  cp "$RC" "$RC.bak.$(date +%s)"
  # remove qualquer export CLIPROXY_API_KEY existente
  if [ "$SHELL_NAME" = "fish" ]; then
    sed -i.tmp '/^set -gx CLIPROXY_API_KEY /d' "$RC" 2>/dev/null || \
      sed -i '' '/^set -gx CLIPROXY_API_KEY /d' "$RC"
    rm -f "$RC.tmp"
    echo "set -gx CLIPROXY_API_KEY $API_KEY" >> "$RC"
  else
    sed -i.tmp '/^export CLIPROXY_API_KEY=/d' "$RC" 2>/dev/null || \
      sed -i '' '/^export CLIPROXY_API_KEY=/d' "$RC"
    rm -f "$RC.tmp"
    {
      echo ""
      echo "# CLIProxyAPI INFOCO (adicionado por setup-opencode-proxy.sh)"
      echo "export CLIPROXY_API_KEY=$API_KEY"
    } >> "$RC"
  fi
  ok "CLIPROXY_API_KEY adicionada em $RC"
else
  warn "$RC não existe. Criando..."
  echo "export CLIPROXY_API_KEY=$API_KEY" > "$RC"
fi

# --- 7) Instalar skill Claude "sicc-cadastros" ---
echo ""
info "Instalando skill sicc-cadastros..."

SKILL_DIR="$HOME/.claude/skills/sicc-cadastros"
SKILL_URL="https://raw.githubusercontent.com/nandovitor/OpenCode/master/skills/sicc-cadastros/SKILL.md"

mkdir -p "$SKILL_DIR"
if curl -fsSL "$SKILL_URL" -o "$SKILL_DIR/SKILL.md"; then
  SIZE=$(wc -c < "$SKILL_DIR/SKILL.md")
  if [ "$SIZE" -lt 500 ]; then
    warn "SKILL.md baixou mas está suspeitamente pequeno ($SIZE bytes)"
  else
    ok "Skill instalada em $SKILL_DIR/SKILL.md ($SIZE bytes)"
  fi
else
  warn "Não consegui baixar a skill. Você pode baixar manualmente depois:"
  warn "  mkdir -p $SKILL_DIR"
  warn "  curl -fsSL $SKILL_URL -o $SKILL_DIR/SKILL.md"
fi

# Se Claude Code CLI estiver instalado, registrar o MCP infoco lá também
if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -q '^infoco'; then
    ok "MCP infoco já está registrado no Claude Code"
  else
    if claude mcp add infoco https://compras.app.br/mcp/documentos --transport http >/dev/null 2>&1; then
      ok "MCP infoco registrado no Claude Code"
    else
      warn "Não consegui registrar MCP no Claude Code automaticamente."
      warn "Roda manualmente: claude mcp add infoco https://compras.app.br/mcp/documentos --transport http"
    fi
  fi
else
  info "Claude Code CLI não está instalado neste PC — pulando registro do MCP no Claude Code"
  info "(A skill funciona no OpenCode mesmo sem Claude Code; o MCP infoco já está no opencode.json)"
fi

# --- 8) Instalar libs de extração de documentos (pandoc, pdfplumber, OCR, ...) ---
echo ""
info "Verificando libs de extração de documentos (pandoc, pdfplumber, OCR...)..."

# Detecta gerenciador de pacotes
if command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
  PKG_INSTALL="sudo dnf install -y"
  PKG_LIST="pandoc poppler-utils tesseract tesseract-langpack-por libreoffice-core libreoffice-writer libreoffice-calc java-21-openjdk-headless ghostscript python3-pip"
elif command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
  PKG_INSTALL="sudo apt-get install -y"
  PKG_LIST="pandoc poppler-utils tesseract-ocr tesseract-ocr-por libreoffice-core libreoffice-writer libreoffice-calc default-jre-headless ghostscript python3-pip"
elif command -v pacman >/dev/null 2>&1; then
  PKG_MGR="pacman"
  PKG_INSTALL="sudo pacman -S --noconfirm"
  PKG_LIST="pandoc poppler tesseract tesseract-data-por libreoffice-fresh jre-openjdk-headless ghostscript python-pip"
elif command -v brew >/dev/null 2>&1; then
  PKG_MGR="brew"
  PKG_INSTALL="brew install"
  PKG_LIST="pandoc poppler tesseract tesseract-lang libreoffice openjdk ghostscript"
else
  warn "Gerenciador de pacotes não detectado (esperado dnf/apt/pacman/brew). Pulando."
  PKG_MGR=""
fi

if [ -n "$PKG_MGR" ]; then
  info "Detectado: $PKG_MGR — instalando libs do sistema (pode pedir sudo)..."
  if $PKG_INSTALL $PKG_LIST 2>&1 | tail -5; then
    ok "Pacotes do sistema instalados"
  else
    warn "Falha ao instalar pacotes do sistema. Continua mesmo assim."
  fi
fi

# Instala libs Python via pip user (independente do PKG_MGR)
if command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
  PIP="$(command -v pip3 || command -v pip)"
  PY_LIBS="pdfplumber pypdf pymupdf python-docx openpyxl pandas camelot-py[cv] ocrmypdf"
  info "Instalando libs Python via $PIP ($PY_LIBS)..."

  # PEP 668: Ubuntu 22.04+, Debian 12+, Fedora 38+ bloqueiam pip install fora de venv
  # Tenta primeiro --user; se falhar com 'externally-managed-environment', tenta --break-system-packages
  PIP_OUTPUT=$($PIP install --user --upgrade $PY_LIBS 2>&1)
  PIP_EXIT=$?
  if [ $PIP_EXIT -ne 0 ] && echo "$PIP_OUTPUT" | grep -q 'externally-managed-environment'; then
    info "PEP 668 detectado (Ubuntu/Debian/Fedora moderno) — retentando com --break-system-packages..."
    PIP_OUTPUT=$($PIP install --user --upgrade --break-system-packages $PY_LIBS 2>&1)
    PIP_EXIT=$?
  fi

  if [ $PIP_EXIT -eq 0 ]; then
    ok "Libs Python instaladas (pdfplumber, camelot, pymupdf, python-docx, openpyxl, pandas, ocrmypdf)"
  else
    warn "Falha em alguma lib Python. Última saída:"
    echo "$PIP_OUTPUT" | tail -5
    warn "Tenta rodar manualmente:"
    warn "  $PIP install --user --upgrade --break-system-packages $PY_LIBS"
    warn "Ou usa pipx: sudo $PKG_MGR install pipx && pipx ensurepath && for lib in $PY_LIBS; do pipx install \"\$lib\"; done"
  fi
else
  warn "pip não encontrado — pulando libs Python. Instala pip primeiro e tenta de novo."
fi

# --- 9) Tudo certo ---
echo ""
echo -e "${G}═══════════════════════════════════════════════════════════${N}"
echo -e "${G}  ✓ Tudo pronto!${N}"
echo -e "${G}═══════════════════════════════════════════════════════════${N}"
echo ""
echo "O que foi configurado:"
echo "  ✓ OpenCode apontando pro proxy Claude da INFOCO"
echo "  ✓ MCP infoco (SICC) registrado no opencode.json"
echo "  ✓ Skill 'sicc-cadastros' instalada em ~/.claude/skills/"
echo ""
echo "Pra começar a usar:"
echo ""
echo "  1) Abre um terminal NOVO (pra carregar a variável de ambiente)"
echo "     ou roda:  ${B}source $RC${N}"
echo ""
echo "  2) Roda:  ${B}opencode${N}"
echo ""
echo "  3) Dentro do OpenCode, digita ${B}/models${N} e seleciona"
echo "     algum modelo de ${B}CLIProxyAPI (INFOCO)${N}"
echo ""
echo "Modelos Claude (Anthropic):"
echo "  • Claude Opus 4.7        (mais inteligente, mais lento)"
echo "  • Claude Sonnet 4.5      (equilíbrio — recomendado pra trabalho)"
echo "  • Claude Haiku 4.5       (rápido e barato — chat curto)"
echo "  • Claude Opus 4.5        (alternativa ao 4.7)"
echo ""
echo "Modelos GPT/Codex (OpenAI):"
echo "  • GPT-5.5                (mais novo)"
echo "  • GPT-5.4                (flagship)"
echo "  • GPT-5.4 Mini           (rápido/barato)"
echo "  • GPT-5.3 Codex          (especializado em código)"
echo "  • GPT Image 2            (geração de imagem)"
echo ""
echo "Pra cadastrar contrato/ARP/aditivo, é só pedir naturalmente:"
echo "  • \"Cadastra esse contrato no SICC\" + anexa o PDF"
echo "  • \"Cria uma ARP da DL 037/2026\""
echo "  • \"Registra aditivo de prazo no contrato 170 até 31/12\""
echo ""
echo "Na primeira vez que usar o MCP infoco, o OpenCode vai abrir uma tela"
echo "de OAuth pra você logar no SICC com sua conta da INFOCO."
echo ""
echo "Dúvidas? Fala com o Fernando."
echo ""
