# setup-opencode-proxy.ps1 — Setup OpenCode + Proxy Claude INFOCO + libs de extração no Windows
# Uso: iwr -useb https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.ps1 | iex
#      depois rodar: Setup-OpenCodeProxy -ApiKey "SUA_CHAVE"
#
# OU em uma linha:
#      $key = "SUA_CHAVE"; iwr -useb https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.ps1 | iex; Setup-OpenCodeProxy -ApiKey $key

function Setup-OpenCodeProxy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    $ErrorActionPreference = "Continue"
    $ProxyUrl = "https://proxy.infocogestaopublica.com.br/v1"
    $SkillUrl = "https://raw.githubusercontent.com/nandovitor/OpenCode/master/skills/sicc-cadastros/SKILL.md"

    # --- helpers ---
    function Write-Ok($msg)   { Write-Host "✓ $msg" -ForegroundColor Green }
    function Write-Info($msg) { Write-Host "ℹ $msg" -ForegroundColor Cyan }
    function Write-Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
    function Write-Err($msg)  { Write-Host "✗ $msg" -ForegroundColor Red }

    # --- 1) Validar chave ---
    if ($ApiKey -notmatch '^[a-f0-9]{48}$') {
        Write-Warn "Chave não parece ter o formato esperado (48 hex chars). Continuando assim mesmo..."
    }

    Write-Host ""
    Write-Info "Configurando OpenCode para usar o proxy CLIProxyAPI da INFOCO"
    Write-Host ""

    # --- 2) Verificar OpenCode ---
    $opencode = Get-Command opencode -ErrorAction SilentlyContinue
    if (-not $opencode) {
        Write-Warn "OpenCode não está instalado neste computador."
        Write-Host ""
        Write-Host "  Instala primeiro com um destes comandos (escolhe um):"
        Write-Host ""
        Write-Host "    # Via Scoop (recomendado):"
        Write-Host "    scoop install opencode"
        Write-Host ""
        Write-Host "    # Via Winget:"
        Write-Host "    winget install anomalyco.opencode"
        Write-Host ""
        Write-Host "    # Via npm (precisa Node.js >=20):"
        Write-Host "    npm install -g opencode-ai"
        Write-Host ""
        Write-Host "  Depois rode este comando de novo."
        return
    }
    Write-Ok "OpenCode encontrado: $($opencode.Source)"

    # --- 3) Testar conectividade com o proxy ---
    Write-Info "Testando conexão com o proxy..."
    try {
        $resp = Invoke-WebRequest -Uri "$ProxyUrl/models" -Headers @{ "Authorization" = "Bearer $ApiKey" } -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-Ok "Proxy respondeu HTTP 200 — chave válida e proxy online"
        } else {
            Write-Err "HTTP $($resp.StatusCode) inesperado. Avisa o Fernando."
            return
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            Write-Err "HTTP 401 — chave inválida. Confere se copiou direito (sem espaços, 48 caracteres)."
        } else {
            Write-Err "Não consegui alcançar o proxy: $($_.Exception.Message)"
        }
        return
    }

    # --- 4) Backup do opencode.json se existir ---
    $opencodeConfig = "$env:USERPROFILE\.config\opencode\opencode.json"
    $opencodeConfigDir = Split-Path $opencodeConfig
    if (-not (Test-Path $opencodeConfigDir)) {
        New-Item -ItemType Directory -Force -Path $opencodeConfigDir | Out-Null
    }
    if (Test-Path $opencodeConfig) {
        $bak = "$opencodeConfig.bak.$(Get-Date -UFormat %s)"
        Copy-Item $opencodeConfig $bak
        Write-Ok "Backup do config anterior: $bak"
    }

    # --- 5) Escrever opencode.json ---
    $configJson = @'
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
'@
    $configJson | Out-File -FilePath $opencodeConfig -Encoding UTF8 -Force
    Write-Ok "opencode.json escrito em: $opencodeConfig (proxy Claude + MCP infoco)"

    # --- 6) Adicionar CLIPROXY_API_KEY como variável de ambiente (User-level) ---
    [Environment]::SetEnvironmentVariable("CLIPROXY_API_KEY", $ApiKey, "User")
    # Também na sessão atual
    $env:CLIPROXY_API_KEY = $ApiKey
    Write-Ok "CLIPROXY_API_KEY adicionada às variáveis de ambiente do usuário"

    # --- 7) Instalar skill Claude "sicc-cadastros" ---
    Write-Host ""
    Write-Info "Instalando skill sicc-cadastros..."
    $skillDir = "$env:USERPROFILE\.claude\skills\sicc-cadastros"
    New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
    try {
        Invoke-WebRequest -Uri $SkillUrl -OutFile "$skillDir\SKILL.md" -UseBasicParsing -ErrorAction Stop
        $size = (Get-Item "$skillDir\SKILL.md").Length
        if ($size -lt 500) {
            Write-Warn "SKILL.md baixou mas está suspeitamente pequeno ($size bytes)"
        } else {
            Write-Ok "Skill instalada em $skillDir\SKILL.md ($size bytes)"
        }
    } catch {
        Write-Warn "Não consegui baixar a skill. Você pode baixar manualmente depois:"
        Write-Warn "  Invoke-WebRequest $SkillUrl -OutFile $skillDir\SKILL.md"
    }

    # MCP no Claude Code (se instalado)
    $claudeCli = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCli) {
        try {
            $mcpList = claude mcp list 2>&1
            if ($mcpList -match '^infoco') {
                Write-Ok "MCP infoco já está registrado no Claude Code"
            } else {
                claude mcp add infoco https://compras.app.br/mcp/documentos --transport http 2>&1 | Out-Null
                Write-Ok "MCP infoco registrado no Claude Code"
            }
        } catch {
            Write-Warn "Não consegui registrar MCP no Claude Code automaticamente."
            Write-Warn "Roda manualmente: claude mcp add infoco https://compras.app.br/mcp/documentos --transport http"
        }
    }

    # --- 8) Instalar libs de extração de documentos via winget ---
    Write-Host ""
    Write-Info "Instalando libs de extração de documentos (pandoc, pdfplumber, OCR...)..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Warn "winget não encontrado. Instala o App Installer da Microsoft Store ou usa Chocolatey/Scoop."
        Write-Warn "Pulando instalação de pacotes do sistema. Libs Python serão instaladas se Python estiver disponível."
    } else {
        $wingetPkgs = @(
            "JohnMacFarlane.Pandoc",                     # pandoc
            "oschwartz10612.Poppler",                    # poppler (pdftotext)
            "UB-Mannheim.TesseractOCR",                  # OCR
            "TheDocumentFoundation.LibreOffice",         # DOC/DOCX/XLS/XLSX headless
            "EclipseAdoptium.Temurin.21.JRE",            # Java pra camelot/tabula
            "ArtifexSoftware.GhostScript",               # camelot dependency
            "Python.Python.3.12"                         # Python
        )
        foreach ($pkg in $wingetPkgs) {
            Write-Host "  → $pkg"
            winget install --id $pkg --silent --accept-package-agreements --accept-source-agreements 2>&1 | Select-String -Pattern "Successfully|already installed|No applicable|error" | Select-Object -First 2
        }
        Write-Ok "Pacotes winget processados (alguns podem já estar instalados)"
    }

    # --- 9) Instalar libs Python ---
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($py) {
        Write-Info "Instalando libs Python via pip (pdfplumber, pymupdf, python-docx, etc.)..."
        $pyLibs = "pdfplumber", "pypdf", "pymupdf", "python-docx", "openpyxl", "pandas", "camelot-py[cv]", "ocrmypdf"
        try {
            & $py.Source -m pip install --user --upgrade @pyLibs 2>&1 | Select-Object -Last 3
            Write-Ok "Libs Python instaladas"
        } catch {
            Write-Warn "Falha em alguma lib Python: $($_.Exception.Message)"
            Write-Warn "Tenta rodar manualmente:"
            Write-Warn "  python -m pip install --user --upgrade $($pyLibs -join ' ')"
        }
    } else {
        Write-Warn "Python não encontrado mesmo após winget install. Reabre o terminal e roda manualmente:"
        Write-Warn "  python -m pip install --user --upgrade pdfplumber pymupdf python-docx openpyxl pandas `"camelot-py[cv]`" ocrmypdf"
    }

    # --- 10) Tudo certo ---
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✓ Tudo pronto!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "O que foi configurado:"
    Write-Host "  ✓ OpenCode apontando pro proxy Claude da INFOCO"
    Write-Host "  ✓ MCP infoco (SICC) registrado no opencode.json"
    Write-Host "  ✓ Skill 'sicc-cadastros' instalada em $env:USERPROFILE\.claude\skills\"
    Write-Host "  ✓ CLIPROXY_API_KEY salva como variável de ambiente do usuário"
    Write-Host "  ✓ Pandoc, Poppler, Tesseract, LibreOffice, Java, Ghostscript, Python (via winget)"
    Write-Host "  ✓ Libs Python: pdfplumber, pymupdf, python-docx, openpyxl, pandas, camelot, ocrmypdf"
    Write-Host ""
    Write-Host "Pra começar a usar:"
    Write-Host ""
    Write-Host "  1) Abre um terminal NOVO (PowerShell ou cmd) — pra carregar as variáveis de ambiente"
    Write-Host ""
    Write-Host "  2) Roda: opencode"
    Write-Host ""
    Write-Host "  3) Dentro do OpenCode, digita /models e seleciona algum modelo de"
    Write-Host "     'CLIProxyAPI (INFOCO)'"
    Write-Host ""
    Write-Host "Modelos Claude (Anthropic):"
    Write-Host "  • Claude Opus 4.7        (mais inteligente, mais lento)"
    Write-Host "  • Claude Sonnet 4.5      (equilíbrio — recomendado pra trabalho)"
    Write-Host "  • Claude Haiku 4.5       (rápido e barato — chat curto)"
    Write-Host ""
    Write-Host "Modelos GPT/Codex (OpenAI):"
    Write-Host "  • GPT-5.5                (mais novo)"
    Write-Host "  • GPT-5.4                (flagship)"
    Write-Host "  • GPT-5.4 Mini           (rápido/barato)"
    Write-Host "  • GPT-5.3 Codex          (especializado em código)"
    Write-Host ""
    Write-Host "Pra cadastrar contrato/ARP/aditivo, é só pedir naturalmente:"
    Write-Host "  • 'Cadastra esse contrato no SICC' + anexa o PDF"
    Write-Host "  • 'Cria uma ARP da DL 037/2026'"
    Write-Host ""
    Write-Host "Dúvidas? Fala com o Fernando."
    Write-Host ""
}

# Se executado diretamente com argumentos, faz o setup direto
if ($args.Count -gt 0) {
    Setup-OpenCodeProxy -ApiKey $args[0]
}
