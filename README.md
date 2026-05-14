# OpenCode Proxy + Skill SICC — Setup INFOCO

Script de instalação automática que configura, num único comando:

1. **OpenCode** apontando pro proxy Claude da INFOCO
2. **MCP `infoco`** (SICC compras.app.br) registrado no OpenCode
3. **Skill `sicc-cadastros`** instalada em `~/.claude/skills/` — cadastra contratos, ARPs e aditivos no SICC com fluxo autônomo

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
| 6 | Baixa a skill `sicc-cadastros` pra `~/.claude/skills/sicc-cadastros/SKILL.md` |
| 7 | (se Claude Code CLI instalado) registra MCP infoco no Claude Code também |
| 8 | Mostra como começar a usar |

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

## Modelos Claude disponíveis

| Modelo | Quando usar |
|---|---|
| `Claude Opus 4.7` | Tarefas mais complexas, raciocínio profundo |
| `Claude Sonnet 4.5` | Equilíbrio — **recomendado pro dia a dia** |
| `Claude Haiku 4.5` | Respostas rápidas, chat curto, mais barato |
| `Claude Opus 4.5` | Alternativa ao 4.7 |

## Pré-requisitos

- **Linux** (Fedora, Ubuntu, Debian, Arch, etc.) ou **macOS**
- **OpenCode** instalado. Se não tiver:
  ```bash
  curl -fsSL https://opencode.ai/install | bash
  ```
  ou (com Node.js 20+):
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
├── setup-opencode-proxy.sh            (script de instalação)
└── skills/
    └── sicc-cadastros/
        └── SKILL.md                   (skill Claude pra cadastros no SICC)
```

## Dúvidas

Fala com o Fernando.
