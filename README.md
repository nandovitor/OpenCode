# OpenCode Proxy — Setup INFOCO

Script de instalação automática do [OpenCode](https://opencode.ai) configurado pra usar o proxy Claude da INFOCO.

## Instalação (1 linha)

Abre um terminal **no seu computador** (Linux ou macOS) e cola:

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s SUA_CHAVE_API
```

Substitui `SUA_CHAVE_API` pela chave individual que você recebeu do Fernando.

## Exemplo

```bash
curl -fsSL https://raw.githubusercontent.com/nandovitor/OpenCode/master/setup-opencode-proxy.sh | bash -s cacaeb4f97f509e305cdbcb92126fac9479c4ea633a6a89f
```

## O que o script faz

1. ✅ Verifica se o OpenCode está instalado (se não, mostra como instalar)
2. ✅ Testa a sua chave contra o proxy antes de mexer em qualquer config
3. ✅ Faz backup do `~/.config/opencode/opencode.json` se já existir
4. ✅ Escreve o config novo apontando pro proxy da INFOCO
5. ✅ Adiciona a variável `CLIPROXY_API_KEY` no seu shell (bash/zsh/fish)
6. ✅ Mostra como começar a usar

## Depois de instalar

1. Abre um terminal **novo** (pra carregar a variável de ambiente)
2. Roda `opencode`
3. Dentro do OpenCode digita `/models` e seleciona algum modelo de **CLIProxyAPI (INFOCO)**

## Modelos disponíveis

| Modelo | Quando usar |
|---|---|
| `Claude Opus 4.7` | Tarefas mais complexas, raciocínio profundo |
| `Claude Sonnet 4.5` | Equilíbrio — **recomendado pro dia a dia** |
| `Claude Haiku 4.5` | Respostas rápidas, chat curto, mais barato |
| `Claude Opus 4.5` | Alternativa ao 4.7 |

## Pré-requisitos

- **Linux** (Fedora, Ubuntu, Debian, Arch, etc.) ou **macOS**
- **OpenCode** instalado. Se não tiver, instala com:
  ```bash
  curl -fsSL https://opencode.ai/install | bash
  ```
  ou (precisa Node.js):
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

## Dúvidas

Fala com o Fernando.
