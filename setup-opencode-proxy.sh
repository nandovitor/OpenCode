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

# --- 7) Instalar skill SICC + MCP no Codex CLI (sicc-codex-toolkit) ---
echo ""
info "Instalando skill SICC + MCP no Codex (sicc-codex-toolkit)..."

if ! command -v npx >/dev/null 2>&1; then
  warn "npx não encontrado — pulando instalação do sicc-codex-toolkit."
  warn "Pra instalar depois, primeiro instala Node.js e roda:"
  warn "  npx --yes sicc-codex-toolkit@latest setup"
  SKIPPED_SICC=1
else
  if npx --yes sicc-codex-toolkit@latest setup 2>&1 | tail -20; then
    ok "Skill SICC + MCP instalados no Codex (~/.codex/)"
  else
    warn "sicc-codex-toolkit setup falhou — tenta rodar manualmente:"
    warn "  npx --yes sicc-codex-toolkit@latest setup"
    SKIPPED_SICC=1
  fi
fi

# --- 8) Tudo certo ---
echo ""
echo -e "${G}═══════════════════════════════════════════════════════════${N}"
echo -e "${G}  ✓ Tudo pronto!${N}"
echo -e "${G}═══════════════════════════════════════════════════════════${N}"
echo ""
echo "O que foi configurado:"
echo "  ✓ OpenCode apontando pro proxy Claude da INFOCO"
echo "  ✓ MCP infoco (SICC) registrado no OpenCode"
if [ -z "${SKIPPED_SICC:-}" ]; then
  echo "  ✓ Skill 'sicc-cadastrar-contrato' instalada no Codex (~/.codex/)"
  echo "  ✓ MCP infoco também registrado no Codex (~/.codex/config.toml)"
  echo "  ✓ Comando ${B}sicc-codex${N} disponível via ~/.codex/bin/"
fi
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
echo "Modelos disponíveis:"
echo "  • Claude Opus 4.7        (mais inteligente, mais lento)"
echo "  • Claude Sonnet 4.5      (equilíbrio — recomendado pra trabalho)"
echo "  • Claude Haiku 4.5       (rápido e barato — chat curto)"
echo "  • Claude Opus 4.5        (alternativa ao 4.7)"
echo ""
if [ -z "${SKIPPED_SICC:-}" ]; then
  echo "Pra extração robusta de PDF/DOCX no SICC (opcional):"
  echo "  ${B}sicc-codex bootstrap-python${N}"
  echo ""
fi
echo "Quando usar o MCP infoco pela primeira vez, o OpenCode vai abrir"
echo "uma tela de OAuth pra você logar no SICC com sua conta da INFOCO."
echo ""
echo "Dúvidas? Fala com o Fernando."
echo ""
