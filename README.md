# OpenCode Proxy + SICC — Setup INFOCO

Script de instalação automática que configura, num único comando:

1. **OpenCode** apontando pro proxy Claude da INFOCO
2. **MCP `infoco`** (SICC compras.app.br) no OpenCode
3. **Skill `sicc-cadastrar-contrato`** + MCP SICC no Codex CLI (via [sicc-codex-toolkit](https://www.npmjs.com/package/sicc-codex-toolkit))

## Instalação (1 linha)

Abre um terminal **no seu computador** (Linux ou macOS) e cola:

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s SUA_CHAVE_API
```

Substitui `SUA_CHAVE_API` pela chave individual que você recebeu do Fernando.

### Exemplo

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
| 6 | Roda `npx sicc-codex-toolkit setup` — instala skill SICC e MCP no Codex (`~/.codex/`) |
| 7 | Mostra como começar a usar |

## Depois de instalar

### Pra usar Claude no OpenCode
1. Abre um terminal **novo** (pra carregar a variável de ambiente)
2. Roda `opencode`
3. Dentro do OpenCode digita `/models` e seleciona algum modelo de **CLIProxyAPI (INFOCO)**

### Pra usar o MCP SICC dentro do OpenCode
1. Pede pra IA algo como *"Liste as organizações do SICC"* ou *"Quais contratos vencidos do tenant X?"*
2. Na primeira vez, o OpenCode vai abrir uma tela de OAuth — você faz login com sua conta INFOCO/SICC
3. A IA usa as ferramentas MCP pra consultar/cadastrar diretamente no SICC

### Pra usar a skill SICC no Codex
1. Instala o Codex CLI (se ainda não tiver)
2. No Codex, a skill `sicc-cadastrar-contrato` já está disponível em `~/.codex/skills/`
3. Roda `sicc-codex draft-payload contrato.pdf` pra extrair dados de PDF/DOCX
4. Pra extração robusta, roda também (opcional): `sicc-codex bootstrap-python`

## Modelos Claude disponíveis

| Modelo | Quando usar |
|---|---|
| `Claude Opus 4.7` | Tarefas mais complexas, raciocínio profundo |
| `Claude Sonnet 4.5` | Equilíbrio — **recomendado pro dia a dia** |
| `Claude Haiku 4.5` | Respostas rápidas, chat curto, mais barato |
| `Claude Opus 4.5` | Alternativa ao 4.7 |

## Pré-requisitos

- **Linux** (Fedora, Ubuntu, Debian, Arch, etc.) ou **macOS**
- **Node.js 20+** (necessário pra OpenCode e pra sicc-codex-toolkit)
- **OpenCode** instalado. Se não tiver:
  ```bash
  curl -fsSL https://opencode.ai/install | bash
  ```
  ou (com npm):
  ```bash
  npm install -g opencode-ai
  ```

## Problemas comuns

**`HTTP 401 — chave inválida`**
A chave foi copiada errada. Confere com o Fernando se é a chave certa pra você e se não copiou com espaços/quebra de linha.

**`Não consegui alcançar o proxy`**
Verifica internet, DNS e firewall. Se for restrição corporativa, talvez precise liberar `proxy.infocogestaopublica.com.br` no firewall.

**`OpenCode não está instalado`**
Instala primeiro (ver pré-requisitos) e roda o script de novo.

**`sicc-codex-toolkit setup falhou`**
Provavelmente Node.js < 20. Atualiza Node e roda manualmente:
```bash
npx --yes sicc-codex-toolkit@latest setup
```

**Tela de OAuth do MCP infoco não abre**
Pode ser problema com o cliente OAuth do compras.app.br. Avisa o Fernando — está em investigação.

## Componentes

- **CLIProxyAPI** (proxy Claude): https://github.com/router-for-me/CLIProxyAPI — rodando em `https://proxy.infocogestaopublica.com.br`
- **OpenCode** (cliente IDE): https://opencode.ai
- **sicc-codex-toolkit** (skill SICC + MCP no Codex): https://www.npmjs.com/package/sicc-codex-toolkit
- **MCP SICC**: `https://compras.app.br/mcp/documentos`

## Dúvidas

Fala com o Fernando.
