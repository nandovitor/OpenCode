# OpenCode Proxy + Skill SICC — Setup INFOCO

Script de instalação automática que configura, num único comando:

1. **OpenCode** apontando pro proxy Claude da INFOCO
2. **MCP `infoco`** (SICC compras.app.br) registrado no OpenCode
3. **Skill `sicc-cadastros`** instalada em `~/.claude/skills/` — cadastra contratos, ARPs e aditivos no SICC com fluxo autônomo

## Instalação (1 linha por sistema)

Substitui `SUA_CHAVE_API` pela chave individual que você recebeu do Fernando.

### 🐧 Fedora / Linux Mint / openSUSE / Arch

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s SUA_CHAVE_API
```

Detecta automaticamente `dnf`/`apt`/`pacman` e instala todos os pacotes do sistema + libs Python.

### 🐧 Ubuntu / Debian

Mesmo comando do Fedora — o script detecta `apt` automaticamente:

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s SUA_CHAVE_API
```

**Nota Ubuntu 22.04+ / Debian 12+:** o script lida automaticamente com o erro PEP 668 ("externally-managed-environment") usando `--break-system-packages` no pip.

### 🍎 macOS

Mesmo comando:

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s SUA_CHAVE_API
```

Detecta `brew`. **Pré-requisito:** Homebrew instalado (https://brew.sh).

### 🪟 Windows 10 / 11 (PowerShell — nativo, sem WSL)

Abre o **PowerShell como Administrador** (clique direito no menu Iniciar → "Terminal (Admin)") e cola:

```powershell
$key = "SUA_CHAVE_API"
iwr -useb https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.ps1 | iex
Setup-OpenCodeProxy -ApiKey $key
```

O script:
- Instala OpenCode (se não tiver), Pandoc, Poppler, Tesseract, LibreOffice, Java, Ghostscript, Python — tudo via `winget`
- Configura `~/.config/opencode/opencode.json`
- Salva `CLIPROXY_API_KEY` como variável de ambiente do usuário (persiste entre sessões)
- Instala libs Python (pdfplumber, pymupdf, etc.)
- Baixa a skill `sicc-cadastros`

**Pré-requisitos Windows:**
- Windows 10 versão 1809+ ou Windows 11 (vem com `winget`). Se não tiver, instala o "App Installer" da Microsoft Store.
- OpenCode (se não tiver): `winget install anomalyco.opencode` ou `scoop install opencode`.

### 🪟 Windows via WSL (alternativa — só se quiser tudo em Linux)

Se preferir usar WSL (Ubuntu rodando dentro do Windows):

```bash
# 1) No PowerShell admin, instala WSL:
wsl --install -d Ubuntu

# 2) Reinicia, abre o Ubuntu, e roda:
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s SUA_CHAVE_API
```

### Exemplo (Linux/macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s cacaeb4f97f509e305cdbcb92126fac9479c4ea633a6a89f
```

## O que o script faz

| Passo | Ação |
|---|---|
| 1 | Verifica se OpenCode está instalado |
| 2 | Testa sua chave contra o proxy antes de mexer em qualquer config |
| 3 | Faz backup do `~/.config/opencode/opencode.json` se já existir |
| 4 | Escreve config novo com proxy Claude + MCP `infoco` |
| 5 | Adiciona `CLIPROXY_API_KEY` no seu shell rc (bash/zsh/fish) |
| 6 | Baixa a skill `sicc-cadastros` pra `~/.claude/skills/sicc-cadastros/SKILL.md` |
| 7 | (se Claude Code CLI instalado) registra MCP infoco no Claude Code também |
| 8 | Instala libs de extração de documentos (pandoc, pdfplumber, OCR, etc.) — **pede sudo** |
| 9 | Mostra como começar a usar |

### Libs instaladas no passo 8

Auto-detecta `dnf` (Fedora), `apt` (Ubuntu/Debian), `pacman` (Arch) ou `brew` (macOS) e instala:

**Sistema:** `pandoc`, `poppler-utils` (pdftotext), `tesseract` + langpack-por (OCR), `libreoffice` (DOC/XLS), `java` (pra camelot/tabula), `ghostscript`, `python3-pip`

**Python (via pip --user):** `pdfplumber` (tabelas PDF), `pymupdf` (PDF rápido), `python-docx` (DOCX), `openpyxl` (XLSX), `pandas`, `camelot-py[cv]` (fallback tabelas), `ocrmypdf` (PDF escaneado)

Essas libs são o que a skill `sicc-cadastros` usa pra extrair itens em cascata (tenta `pdfplumber` primeiro, cai pra `camelot`, depois `pdftotext -layout`, e por último OCR).

## Atualizando a skill depois (se já instalou antes)

Sempre que o Fernando publicar uma melhoria na skill, **cada pessoa do time** pode atualizar a versão local com 1 linha:

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/update-skills.sh | bash
```

Esse comando:
- Baixa a versão mais nova de cada skill publicada no repo
- Compara com o que já está em `~/.claude/skills/`
- Substitui só se houver diferença real
- Reporta quantas skills foram atualizadas

Não mexe em mais nada — só nas skills. Seguro rodar quantas vezes quiser.

## Depois de instalar

### Pra usar Claude no OpenCode
1. Abre um terminal **novo** (pra carregar a variável de ambiente)
2. Roda `opencode`
3. Dentro do OpenCode digita `/models` e seleciona algum modelo de **CLIProxyAPI (INFOCO)**

### Pra cadastrar contratos/ARPs/aditivos no SICC
Pede em linguagem natural — a skill `sicc-cadastros` ativa automaticamente:

- *"Cadastra esse contrato no SICC"* + anexa o PDF
- *"Cria uma ARP da DL 037/2026 — anexei o documento"*
- *"Registra aditivo de prazo no contrato 170, nova validade 31/12/2026"*

A skill faz o fluxo **completo** sem te perguntar nada:
1. Identifica o tenant pelo nome do órgão no documento
2. Resolve IDs (unidade, modalidade, objeto resumido) consultando o MCP
3. Verifica se já não tem contrato com mesmo número
4. Monta o payload no formato exato esperado pelo SICC
5. Chama `cadastrar_contrato_ata` ou `cadastrar_aditivo_tool`
6. Reporta o ID criado

Só interrompe se houver ambiguidade real (2+ matches igualmente prováveis) ou dado obrigatório faltando.

## Modelos disponíveis

### Claude (Anthropic)
| Modelo | Quando usar |
|---|---|
| `Claude Opus 4.7` | Tarefas mais complexas, raciocínio profundo |
| `Claude Sonnet 4.5` | Equilíbrio — **recomendado pro dia a dia** |
| `Claude Haiku 4.5` | Respostas rápidas, chat curto, mais barato |
| `Claude Opus 4.5` | Alternativa ao 4.7 |

### GPT / Codex (OpenAI)
| Modelo | Quando usar |
|---|---|
| `GPT-5.5` | Mais novo da OpenAI |
| `GPT-5.4` | Flagship — boa segunda opção quando Claude rate-limitar |
| `GPT-5.4 Mini` | Rápido e barato — alternativa ao Haiku |
| `GPT-5.3 Codex` | Especializado em código |
| `GPT Image 2` | Geração de imagem |

**Dica:** se Claude rate-limitar (todo mundo na conta da INFOCO), troca pra GPT-5.4 ou GPT-5.5 pra continuar trabalhando.

## Pré-requisitos

- **Linux** (Fedora, Ubuntu, Debian, Arch, etc.) ou **macOS**
- **OpenCode** instalado.

### Como instalar o OpenCode

**Recomendado (instalador oficial bash):**
```bash
curl -fsSL https://opencode.ai/install | bash
```

Alternativa (com Node.js 20+):
```bash
npm install -g opencode-ai
```

### ⚠️ NÃO use o Flatpak

O pacote Flatpak do opencode é mantido pela comunidade e atualmente apresenta erro `Failed to resolve transaction: Id is out of bitmap range` em algumas máquinas (cache OSTree corrompido). **Use o instalador oficial bash acima** — é mais leve, mais rápido e funciona em qualquer Linux.

## Problemas comuns

**`HTTP 401 — chave inválida`**
A chave foi copiada errada. Confere com o Fernando se é a chave certa pra você e se não copiou com espaços/quebra de linha.

**`Não consegui alcançar o proxy`**
Verifica internet, DNS e firewall. Se for restrição corporativa, talvez precise liberar `proxy.infocogestaopublica.com.br` no firewall.

**`OpenCode não está instalado`**
Instala primeiro (ver pré-requisitos) e roda o script de novo.

**Tela de OAuth do MCP infoco não abre**
Pode ser problema com o cliente OAuth do compras.app.br. Avisa o Fernando — está em investigação.

**A skill não está sendo invocada automaticamente**
Em alguns clientes você precisa referenciar explicitamente: peça *"Use a skill sicc-cadastros para cadastrar esse contrato"*. Em Claude Code, a skill é descoberta automaticamente quando o `description` da frontmatter bate com o pedido.

## Componentes

- **CLIProxyAPI** (proxy Claude): https://github.com/router-for-me/CLIProxyAPI — rodando em `https://proxy.infocogestaopublica.com.br`
- **OpenCode** (cliente IDE): https://opencode.ai
- **Skill `sicc-cadastros`**: ver [`skills/sicc-cadastros/SKILL.md`](skills/sicc-cadastros/SKILL.md)
- **MCP SICC**: `https://compras.app.br/mcp/documentos`

## Estrutura do repo

```
.
├── README.md                          (este arquivo)
├── setup-opencode-proxy.sh            (instalação Linux/macOS — bash)
├── setup-opencode-proxy.ps1           (instalação Windows — PowerShell)
├── update-skills.sh                   (atualiza só as skills, idempotente)
└── skills/
    └── sicc-cadastros/
        └── SKILL.md                   (skill Claude pra cadastros no SICC)
```

## Dúvidas

Fala com o Fernando.
