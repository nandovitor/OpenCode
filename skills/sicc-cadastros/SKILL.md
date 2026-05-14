---
name: sicc-cadastros
description: Cadastra contratos, Atas de Registro de Preço (ARPs) e aditivos no SICC INFOCO via MCP "infoco" (https://compras.app.br/mcp/documentos). Execute fluxo autônomo — resolva todos os IDs obrigatórios via tools get_*, monte o payload conforme schema, e chame a tool de cadastro sem pedir confirmação ao usuário. Use quando o pedido envolver "cadastrar contrato", "criar ata", "registrar ARP" (Ata de Registro de Preço), "adicionar aditivo", "termo aditivo", "cadastrar adesão", ou quando houver um PDF/DOCX de contrato/ata/aditivo para importar no SICC.
---

# Skill: Cadastros no SICC (Contratos / ARPs / Aditivos)

## Princípio

**Execute sem perguntar.** Resolva IDs por consulta às tools `get_*`, decida por contexto e nomes do documento, monte o payload e chame a tool de cadastro. Só pare e pergunte se houver ambiguidade real (≥2 matches igualmente prováveis) ou campo obrigatório que não pode ser inferido do texto/documento.

Não invente IDs. Sempre resolva via MCP.
Não peça confirmação intermediária ao usuário.
Não instale dependências durante o fluxo.

---

## Tools MCP (servidor `infoco`)

Todas as tools abaixo estão no servidor MCP `infoco` configurado em `~/.config/opencode/opencode.json` (e em `~/.claude.json` se Claude Code estiver em uso). Tool IDs aparecem como `mcp__infoco__<nome>`.

### Listagem / resolução de IDs
| Tool | Uso |
|---|---|
| `mcp__infoco__get_organizacoes_tool` | Lista tenants (organizações) que o usuário atende |
| `mcp__infoco__get_unidades_tool` | Lista unidades gestoras/participantes de um tenant |
| `mcp__infoco__get_objeto_resumido_tool` | Lista objetos resumidos (categorias) de um tenant |
| `mcp__infoco__get_modalidades_licitacao_tool` | Lista modalidades (PE, PP, DL, INEX, CRED, CONC-E, ADE, CHP, etc.) |
| `mcp__infoco__get_tipos_termos_tool` | Lista tipos de termo aditivo (Prazo, Valor, Prazo+Valor, Reequilíbrio, Reajuste, Repactuação, Quantitativo, Qualitativo, Dotação, Rescisão, Renovação, etc.) |
| `mcp__infoco__get_contratos_tool` | Lista contratos de um tenant (filtros: page, perPage) |
| `mcp__infoco__search_contrato_by_numero_tool` | Busca contrato por número (verificar duplicidade / encontrar alvo de aditivo) |

### Cadastro
| Tool | Uso |
|---|---|
| `mcp__infoco__cadastrar_contrato_ata` | Cadastra contrato (`tipo: "CONTRATO"`) **ou** ARP/Ata (`tipo: "ATA"`) |
| `mcp__infoco__cadastrar_aditivo_tool` | Cadastra aditivo (apostilamento/rescisão) em contrato existente |

---

## Fluxos

### Fluxo A — Cadastrar CONTRATO ou ARP

#### Passo 1. Determinar tenant
- Chame `get_organizacoes_tool` (sem args).
- Se retornar **1 só** tenant: use direto.
- Se retornar **vários**: identifique pelo nome da prefeitura/órgão no texto do documento (campo "Contratante", cabeçalho, brasão).
- Se **2+ matches igualmente prováveis**: pergunte qual.

#### Passo 2. Resolver IDs auxiliares (em paralelo quando possível)
Para o `tenant_id` resolvido:
- `get_unidades_tool({ tenant_id })` → identificar `unidade_gerenciadora_id` por nome (ex.: "Secretaria Municipal de Saúde") no documento. Se documento listar várias, a primeira citada como gestora é a gerenciadora. Se não houver dado explícito, use a primeira unidade administrativa da listagem.
- `get_modalidades_licitacao_tool({ tenant_id })` → identificar `modalidade_id` por sigla/nome no documento ("Dispensa de Licitação" → DL, "Pregão Eletrônico" → PE, "Inexigibilidade" → INEX, "Adesão" → ADE, "Credenciamento" → CRED).
- `get_objeto_resumido_tool({ tenant_id })` → identificar `objeto_resumido_id` por match semântico com o objeto do contrato (ex.: "Manutenção de poços artesianos" → categoria "Serviços de Engenharia / Manutenção"). Use o match mais específico disponível.

#### Passo 3. Verificar duplicidade
- `search_contrato_by_numero_tool({ tenant_id, numero })` com o número do contrato extraído.
- Se já existe: **PARE e reporte** — não cadastre duplicado.

#### Passo 4. Montar payload e cadastrar
Payload validado por schema zod no toolkit oficial — siga **exatamente**:

```json
{
  "tenant_id": "<string do passo 1>",
  "documentos": [
    {
      "contrato_ata": {
        "data": "YYYY-MM-DD",
        "data_validade": "YYYY-MM-DD",
        "numero": "<string>",
        "objeto": "<string completo do contrato — NÃO usar resumo genérico>",
        "objeto_resumido_id": <int>,
        "tipo": "CONTRATO",
        "unidade_gerenciadora_id": <int>,
        "unidades_participantes": [<int>, ...],
        "valor": <number>
      },
      "fornecedor": {
        "cnpj_cpf": "<14 dígitos PJ ou 11 PF, SEM máscara>",
        "razao_social": "<string>"
      },
      "licitacao": {
        "modalidade_id": <int>,
        "numero": "<string, ex: '037/2026'>",
        "numero_processo_adm": "<string, ex: '2026.0001.000123'>",
        "objeto": "<string, geralmente igual ao contrato.objeto>"
      },
      "lotes": []
    }
  ]
}
```

**Para ARP (Ata de Registro de Preço):** mude apenas `tipo: "ATA"`. Resto do payload é igual.

Regras de preenchimento:
- `data` / `data_validade`: formato ISO `YYYY-MM-DD`. Se vier no documento como "DD/MM/YYYY", converta.
- `cnpj_cpf`: APENAS dígitos. Remova `.`, `/`, `-`.
- `unidades_participantes`: array de inteiros. Se documento não citar adesão de outras unidades, use `[unidade_gerenciadora_id]` (apenas a gestora).
- `valor`: número (não string), em reais. Se o doc disser "R$ 64.635,00", envie `64635.0`.
- `objeto` (contrato e licitação): use o objeto **completo do documento**, não substitua por descrição genérica.
- `lotes`: **OBRIGATÓRIO seguir a seção "Extração de Itens" abaixo**. Nunca enviar vazio se o documento tiver tabela de itens. Nunca pular item.

Chame `cadastrar_contrato_ata` com o payload. Reporte o ID retornado.

#### Extração de Itens (CRÍTICO — não pular nenhum)

**Onde os itens aparecem no documento:**
- **Cláusula "Do Objeto"** ou **"Dos Bens/Serviços"** — descrição narrativa pode listar itens
- **Anexo I** (mais comum) — tabela com colunas: Item, Descrição, Quantidade, Unidade, Valor Unitário, Valor Total
- **Tabela de Preços / Planilha Orçamentária** — geralmente no fim do documento
- **Mapa de Lances** (em pregão) — anexo separado às vezes
- **ARP especificamente:** sempre tem tabela de itens com preços registrados — pode ter 1 a 200+ itens

**⚠️ Por que precisa de batch mode (não ignore):** Modelos Claude têm limite de tokens **de saída** ~64k. Um payload com 1000 itens inline = ~200k tokens de saída → cortado em ~500 itens, e a contagem fica falsamente "OK" porque o modelo perdeu a referência da contagem original. **Resultado real observado: de 1000 itens, só 500 foram cadastrados.** Pra evitar isso, **TODO documento com >50 itens DEVE usar arquivo acumulador no disco** — não tentar montar o array `itens` direto na resposta.

**Procedimento obrigatório de extração:**

### 1. Identifique a tabela e CONTE os itens DE FORMA DETERMINÍSTICA

- Procure cabeçalhos como: `ITEM | DESCRIÇÃO | QUANTIDADE | UNID. | VALOR UNIT. | VALOR TOTAL` ou variações (`Nº | Especificação | Qtd | Un | Preço Unit. | Preço Total`)
- Identifique lotes separados (`LOTE 1`, `LOTE 2`, ...) se houver
- **Conte os itens com Bash, não de cabeça.** Use o número do item explícito no doc:

```bash
# Exemplo: PDF convertido pra texto em /tmp/doc.txt — conta linhas que começam com "ITEM N" ou "1\t", "2\t" etc.
# Ajuste o padrão regex à estrutura específica do documento.
grep -cE '^[[:space:]]*[0-9]+[[:space:]]+[A-Z]' /tmp/doc.txt > /tmp/sicc-doc-count.txt
cat /tmp/sicc-doc-count.txt
```

- Confirme visualmente que o último item do doc tem o número que vc esperaria (ex: "tabela vai do item 1 ao 1000 → doc_count = 1000").
- Persista o número: `echo "1000" > /tmp/sicc-doc-count.txt`

### 2. Inicialize o arquivo acumulador de itens

```bash
# Limpe acumuladores anteriores
rm -f /tmp/sicc-items.jsonl
touch /tmp/sicc-items.jsonl
```

Vamos usar formato **JSONL** (1 item JSON por linha) — fácil de acrescentar incrementalmente e contar com `wc -l`.

### 3. Extraia em LOTES (batches) de 50 itens, anexando ao arquivo

**Regra inviolável:** se `doc_count > 50`, **NÃO tente** montar o array `itens` inline na resposta. Em vez disso:

Para cada batch de 50 itens:

1. Ler do documento APENAS os itens N até N+49
2. Gerar 50 linhas JSON, **uma por linha** (JSONL):
   ```jsonl
   {"numero":1,"descricao":"...","quantidade":10,"unidade_medida":"UN","valor_unitario":15.50,"valor_total":155.00,"marca":"...","codigo":"..."}
   {"numero":2,...}
   ...
   ```
3. Apender ao arquivo com a tool `Write` em modo append, ou usar Bash:
   ```bash
   cat >> /tmp/sicc-items.jsonl <<'EOF'
   {"numero":1,"descricao":...}
   ...
   EOF
   ```
4. Após cada batch, **verifique** com `wc -l /tmp/sicc-items.jsonl` — confirme que cresceu por exatamente 50.

Repita até cobrir todos os itens. Para 1000 itens = **20 iterações de 50**.

**Por que 50 e não 100?** Cada item tem ~200-400 tokens (descrição longa + especificação). 50 itens = ~10-20k tokens por chamada Write — bem dentro do limite. 100 já fica apertado em documentos com descrição rica.

### 4. Estrutura de cada item (uma linha do JSONL)

```json
{
  "numero": <int>,
  "descricao": "<string completa — especificação técnica/marca/modelo INCLUSOS>",
  "quantidade": <number>,
  "unidade_medida": "<UN|KG|M|M²|M³|L|SERV|HORA|MÊS|...>",
  "valor_unitario": <number sem máscara>,
  "valor_total": <number — quantidade × valor_unitario>,
  "marca": "<string — se houver>",
  "codigo": "<string — CATMAT/CATSER se houver>",
  "lote_numero": <int — opcional, só se múltiplos lotes>
}
```

### 5. Validação determinística APÓS extração

**Execute esses comandos Bash. Se qualquer um falhar, PARE.**

```bash
DOC_COUNT=$(cat /tmp/sicc-doc-count.txt)
EXTRACTED_COUNT=$(wc -l < /tmp/sicc-items.jsonl)
echo "DOC_COUNT=$DOC_COUNT  EXTRACTED=$EXTRACTED_COUNT"
[ "$DOC_COUNT" -eq "$EXTRACTED_COUNT" ] || { echo "✗ CONTAGEM DIVERGE — não cadastre"; exit 1; }

# Verifica que cada linha é JSON válido
python3 -c "
import json, sys
with open('/tmp/sicc-items.jsonl') as f:
    for i, line in enumerate(f, 1):
        line = line.strip()
        if not line: continue
        try: json.loads(line)
        except Exception as e: print(f'Linha {i} JSON inválido: {e}'); sys.exit(1)
print('✓ JSONL válido')
"

# Verifica unicidade dos números de item (sem duplicatas, sem pulos)
python3 -c "
import json
nums = []
with open('/tmp/sicc-items.jsonl') as f:
    for line in f:
        line = line.strip()
        if line: nums.append(json.loads(line)['numero'])
expected = list(range(min(nums), max(nums)+1))
missing = sorted(set(expected) - set(nums))
dups = [n for n in set(nums) if nums.count(n) > 1]
if missing: print(f'✗ NÚMEROS FALTANDO: {missing[:20]}{\"...\" if len(missing)>20 else \"\"}'); exit(1)
if dups: print(f'✗ NÚMEROS DUPLICADOS: {dups[:20]}'); exit(1)
print(f'✓ Sequência completa: {min(nums)}..{max(nums)} ({len(nums)} itens)')
"

# Soma dos valores fecha com o valor do contrato
python3 -c "
import json
total = 0.0
with open('/tmp/sicc-items.jsonl') as f:
    for line in f:
        line = line.strip()
        if line: total += json.loads(line)['valor_total']
print(f'SOMA_ITENS={total:.2f}')
" > /tmp/sicc-soma.txt
SOMA=$(cat /tmp/sicc-soma.txt | grep -oP '[\d.]+')
echo "SOMA=$SOMA  VALOR_CONTRATO=$VALOR_CONTRATO"
# Conferir: |SOMA - VALOR_CONTRATO| < 0.10
```

**Se contagem, sequência, JSON ou soma falharem → PARE, mostre qual item caiu fora, NÃO cadastre.**

### 6. Monte o payload final lendo o JSONL

**Não escreva os 1000 itens inline na sua resposta.** Use Python/jq pra montar o payload final do disco:

```bash
python3 <<'PYEOF'
import json
with open('/tmp/sicc-items.jsonl') as f:
    itens = [json.loads(l) for l in f if l.strip()]

# Agrupar por lote_numero (se existir) ou montar lote único
from collections import defaultdict
by_lot = defaultdict(list)
for it in itens:
    lot = it.pop('lote_numero', 1)
    by_lot[lot].append(it)

lotes = [
    {
        "numero": lot_num,
        "itens": items_in_lot,
        "valor_total": round(sum(i['valor_total'] for i in items_in_lot), 2)
    }
    for lot_num, items_in_lot in sorted(by_lot.items())
]

# Carregar template do payload (preenchido nos passos anteriores)
payload = json.load(open('/tmp/sicc-payload-base.json'))
payload['documentos'][0]['lotes'] = lotes
json.dump(payload, open('/tmp/sicc-payload-final.json', 'w'), ensure_ascii=False, indent=2)
print(f'Payload montado: {len(itens)} itens em {len(lotes)} lote(s)')
PYEOF
```

### 7. Chame `cadastrar_contrato_ata` passando o payload final do disco

Leia `/tmp/sicc-payload-final.json` e mande pra tool MCP. Se a tool aceitar string JSON direto, ótimo. Se aceitar objeto, parse antes.

**Não tente reescrever os 1000 itens na chamada da tool** — passe o objeto Python/parsed JSON direto.

### 8. Verificação pós-cadastro (não pular)

Após o `cadastrar_contrato_ata` retornar sucesso com `id`, **chame `get_contratos_tool` (ou a tool de detalhe se houver) pra puxar o contrato recém-criado e contar os itens cadastrados**.

```
ITENS_CADASTRADOS = soma de itens em todos os lotes do contrato retornado
Se ITENS_CADASTRADOS != DOC_COUNT → ALERTE e investigue (MCP pode ter truncado).
```

Se houver discrepância na resposta do MCP, **reporte ao usuário com clareza**: "MCP cadastrou X itens mas o documento tinha Y — investigar limite do servidor."

### 9. Casos especiais

- **Documento ≤ 50 itens:** pode montar inline na resposta (sem precisar de arquivo) — mas ainda valide contagem.
- **Múltiplos lotes:** marque cada item com `lote_numero` no JSONL; o agrupamento é feito automaticamente no passo 6.
- **Contrato unitário (1 item global, ex: "construção de prédio"):** `lotes: [{ numero: 1, itens: [{ numero: 1, descricao: <objeto>, quantidade: 1, unidade_medida: "SERV", valor_unitario: <valor>, valor_total: <valor> }] }]`
- **Aditivo de quantitativo:** mesma estrutura, payload separado (ver Fluxo B).
- **Texto narrativo sem tabela:** procure padrões "fornecimento de X unidades de Y, valor unitário R$ Z" — se houver muitos, ainda use batch mode.
- **PDF escaneado:** se `pdftotext` retornar texto vazio/lixo, **PARE** e peça OCR ao usuário.

### 10. Quantidade fracionária e formato de valor

- `quantidade` aceita decimais (`12.5` para metros/kg).
- Valor sempre número, nunca string. "R$ 1.234,56" → `1234.56`. **Não arredonde** — preserve casas decimais conforme documento.

---

### Fluxo B — Cadastrar ADITIVO

#### Passo 1. Identificar tenant
Mesma lógica do Fluxo A passo 1.

#### Passo 2. Encontrar contrato alvo
- `search_contrato_by_numero_tool({ tenant_id, numero })` com o número do contrato original citado no aditivo.
- Capture o ID do contrato.
- Se **não encontrado**: PARE e reporte. (O contrato precisa estar cadastrado antes do aditivo.)

#### Passo 3. Resolver tipo do termo
- `get_tipos_termos_tool({ tenant_id })` → identifique o `tipo_termo_id`. Padrões comuns:
  - "Aditivo de Prazo" → tipo "Prazo"
  - "Aditivo de Valor" → tipo "Valor"
  - "Aditivo de Prazo e Valor" → "Prazo e Valor"
  - "Reequilíbrio Econômico-Financeiro" → "Reequilíbrio"
  - "Reajuste" / "Repactuação" → respectivo
  - "Acréscimo / Supressão Quantitativa" → "Quantitativo"
  - "Rescisão" → "Rescisão"
  - "Renovação" → "Renovação"

#### Passo 4. Montar payload do aditivo

```json
{
  "tenant_id": "<string>",
  "contrato_ata_id": <int — ID retornado pela busca>,
  "aditivo": {
    "tipo_termo_id": <int>,
    "numero": "<string, ex: '001/2026'>",
    "data": "YYYY-MM-DD",
    "data_validade": "YYYY-MM-DD",
    "valor": <number — opcional, só se aditivo afeta valor>,
    "objeto": "<string descritivo do aditivo>"
  }
}
```

Campos por tipo de termo:
- **Prazo**: obrigatório `data_validade` (nova validade). `valor` omitido.
- **Valor**: obrigatório `valor` (novo valor total ou acréscimo, conforme prática do tenant). `data_validade` omitido.
- **Prazo e Valor**: ambos.
- **Reequilíbrio / Reajuste / Repactuação**: `valor` (novo). Sem mudança de prazo.
- **Quantitativo**: `valor` (novo total).
- **Rescisão**: `data` (data de rescisão).
- **Renovação**: `data_validade` (nova).

Chame `cadastrar_aditivo_tool` com o payload. Reporte o ID retornado.

---

## Extração de dados de documento (PDF/DOCX/TXT)

Quando o usuário enviar um arquivo:

1. Use a ferramenta `Read` (ou equivalente da plataforma) para ler o conteúdo. Para PDF, pode ser necessário extrair texto via `pdftotext` ou similar disponível no shell.
2. Identifique:
   - **Número** (procure "Contrato Nº", "DL", "PE", "CRED", "INEX" seguido de identificador)
   - **Data de assinatura** (procure "Aos X dias do mês de", ou data no rodapé)
   - **Data de validade** (cláusula "Vigência" / "Prazo")
   - **Objeto** (cláusula "Objeto" — texto completo)
   - **Valor** (procure "R$ X,XX" ou "valor global de")
   - **Contratado/Fornecedor**: razão social + CNPJ (procure "CNPJ")
   - **Modalidade**: na cláusula "Considerando" ou "Fundamentação" (DL, PE, INEX, etc.)
   - **Número do processo administrativo**: padrão "Processo Adm. Nº X" ou "Proc. X"
   - **Unidade gestora**: cabeçalho ou "Por meio da Secretaria de..."
   - **ITENS** (Anexo I, Tabela de Preços, Planilha Orçamentária, Mapa de Lances) — siga obrigatoriamente a seção "Extração de Itens" do Fluxo A. Para ARP, espere tabela longa (até 200+ linhas). Para contrato unitário, ainda assim monte 1 lote + 1 item.

3. **Para PDFs com tabelas:** se o texto extraído estiver bagunçado/colunas misturadas, tente extrair de novo com modo de layout (`pdftotext -layout arquivo.pdf -`) ou similar. Tabelas em PDF perdem estrutura sem flag de layout — e itens em coluna ficam embaralhados.

4. **Para DOCX:** tabelas são preservadas em estrutura — extraia célula por célula.

5. **Para imagens/PDFs escaneados:** se o texto não puder ser lido (PDF escaneado sem OCR), reporte ao usuário: "PDF parece escaneado/sem texto. Preciso de OCR ou que você cole os itens manualmente." NÃO cadastre nada cego.

6. Monte o payload conforme acima.

---

## Regras invioláveis

- ❌ **Nunca** invente IDs. Sempre resolva via `get_*` tools.
- ❌ **Nunca** envie `cnpj_cpf` com máscara — só dígitos.
- ❌ **Nunca** mande `unidades_participantes: []` vazio — use `[unidade_gerenciadora_id]` como fallback.
- ❌ **Nunca** substitua o `objeto` do documento por resumo genérico. Use o texto completo.
- ❌ **Nunca** cadastre se `search_contrato_by_numero_tool` encontrar o mesmo número.
- ❌ **Nunca** pule item do documento. Se a tabela tem 47 linhas, o payload tem 47 itens — ponto.
- ❌ **Nunca** cadastre se a validação de itens falhar (contagem ou soma divergente). PARE e reporte.
- ❌ **Nunca** descarte marca/modelo/código do item. Preserve na `descricao` e/ou `marca`/`codigo`.
- ❌ **Nunca** invente quantidade ou valor unitário "pra fechar a conta". Se não bate, é erro de extração — releia o doc.
- ❌ **Nunca** tente montar o array `itens` inline na resposta quando o doc tiver >50 itens. **Use SEMPRE** arquivo acumulador `/tmp/sicc-items.jsonl` (causa documentada: limite de 64k tokens de saída do Claude trunca em ~500 itens — perdeu 50% num teste real de 1000 itens).
- ❌ **Nunca** assuma que `EXTRACTED == DOC_COUNT` mentalmente — valide com `wc -l` no arquivo JSONL e `diff` com a contagem do doc gravada em `/tmp/sicc-doc-count.txt`.
- ❌ **Nunca** dispense a checagem pós-cadastro: depois do `cadastrar_contrato_ata` retornar sucesso, busque o contrato criado e confira que o número de itens cadastrados bate com o do documento.
- ✅ **Sempre** rode resolução de IDs em paralelo quando possível (3 chamadas independentes em uma rodada).
- ✅ **Sempre** valide formato de datas (ISO) e número (sem ponto de milhar).
- ✅ **Sempre** conte itens ANTES de extrair (Bash + grep, gravado em arquivo) e revalide a contagem ao final (`wc -l`).
- ✅ **Sempre** valide `soma de valor_total dos itens ≈ contrato_ata.valor` (diferença ≤ R$ 0,10) via script Python lendo o JSONL.
- ✅ **Sempre** preserve a ordem dos itens conforme o documento (item 1 do doc = item 1 do payload).
- ✅ **Sempre** extraia em batches de 50 quando `doc_count > 50`, gravando direto no JSONL e validando `wc -l` após cada batch (deve crescer exatamente 50).
- ✅ **Sempre** monte o payload final via script Python lendo `/tmp/sicc-items.jsonl` — nunca digite os itens inline na resposta.
- ✅ **Sempre** reporte o ID do registro criado ao final, junto com `itens_cadastrados=<N>/doc_count=<M>`.

---

## Padrão de resposta final

Ao concluir o cadastro com sucesso, responda com:

```
✓ <Tipo> cadastrado no SICC.

ID: <id>
Tenant: <tenant_id>
Número: <numero>
Itens: <N> cadastrados / <M> no documento  ← OBRIGATÓRIO mostrar essas 2 contagens
Lotes: <K>
Valor total: R$ <X>
<resumo de 1 linha com objeto e fornecedor/contraparte>
```

⚠️ Se `N != M`, **não** marque como sucesso — sinalize com `⚠ DIVERGÊNCIA` e descreva o que faltou.

Ao falhar/parar:
```
✗ Não cadastrei. Motivo: <duplicidade | ambiguidade | dado faltante | itens faltando>
<o que preciso pra continuar, se aplicável>
```
