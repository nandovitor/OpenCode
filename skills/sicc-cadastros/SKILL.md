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

**Procedimento obrigatório de extração:**

1. **Identifique a tabela de itens** no documento. Procure cabeçalhos como:
   - "ITEM | DESCRIÇÃO | QUANTIDADE | UNID. | VALOR UNIT. | VALOR TOTAL"
   - "Nº | Especificação | Qtd | Un | Preço Unit. | Preço Total"
   - "LOTE 1 / LOTE 2 / ..." (quando há lotes separados)

2. **Conte os itens** ANTES de extrair. Exemplo: "tabela tem 47 linhas de item (números 1 a 47)". Esse número vai ser usado pra validar no fim.

3. **Extraia TODOS os itens**, linha por linha. Se a tabela quebrar entre páginas, continue na próxima. Se o documento tiver "(...continua)" ou "Continuação do Anexo I", siga até o final.

4. **Estrutura de cada item:**
   ```json
   {
     "numero": <int — número do item, geralmente 1, 2, 3, ...>,
     "descricao": "<string — descrição completa, INCLUINDO especificação técnica/marca/modelo>",
     "quantidade": <number>,
     "unidade_medida": "<string — UN, KG, M, M², M³, L, SERV, HORA, MÊS, etc.>",
     "valor_unitario": <number — em reais, sem máscara>,
     "valor_total": <number — quantidade × valor_unitario>,
     "marca": "<string — se aparecer 'Marca: X' ou 'Modelo: Y'>",
     "codigo": "<string — se houver código de catálogo/CATMAT/CATSER>"
   }
   ```

5. **Estrutura de cada lote:**
   ```json
   {
     "numero": <int — número do lote, geralmente 1>,
     "itens": [<array de itens>],
     "valor_total": <number — soma de valor_total dos itens>
   }
   ```

6. **Casos especiais:**
   - **Documento com 1 lote único contendo N itens:** monte como `lotes: [{ numero: 1, itens: [...N itens] }]`
   - **Documento com múltiplos lotes (LOTE 1, LOTE 2, ...):** monte um objeto por lote, cada um com seus próprios itens
   - **Contrato com 1 único item global (ex: "construção de prédio"):** ainda assim monte `lotes: [{ numero: 1, itens: [{ numero: 1, descricao: <objeto>, quantidade: 1, unidade_medida: "SERV", valor_unitario: <valor_contrato>, valor_total: <valor_contrato> }] }]`
   - **Aditivo de quantitativo:** itens novos seguem mesma estrutura, em campo separado do aditivo (ver Fluxo B)
   - **Texto narrativo sem tabela explícita:** procure padrões "fornecimento de X unidades de Y, valor unitário R$ Z" e gere o item a partir do texto

7. **Marcas/modelos:** se a descrição diz "Notebook DELL Latitude 5430 i7 16GB SSD 512GB", extraia `descricao` completo + `marca: "DELL Latitude 5430"`. Não jogue a marca fora.

8. **Validação obrigatória ANTES de chamar `cadastrar_contrato_ata`:**

   ```
   COUNT_DOC = número de itens contado no documento (passo 2)
   COUNT_EXTRACTED = soma de itens em todos os lotes
   SOMA_ITENS = soma de valor_total de todos os itens
   VALOR_CONTRATO = contrato_ata.valor

   Verificar:
   ✓ COUNT_DOC == COUNT_EXTRACTED (mesma contagem)
   ✓ |SOMA_ITENS - VALOR_CONTRATO| < 0.10 (diferença ≤ 10 centavos por arredondamento)
   ```

   Se **qualquer validação falhar:** PARE, reporte qual item pode ter sido pulado/duplicado, NÃO cadastre.

9. **Quantidades fracionárias:** aceite normalmente (ex: `quantidade: 12.5` para metros, kg, etc.).

10. **Valores em real:** sempre número, não string. "R$ 1.234,56" → `1234.56`. Nunca arredonde — preserve casas decimais.

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
- ✅ **Sempre** rode resolução de IDs em paralelo quando possível (3 chamadas independentes em uma rodada).
- ✅ **Sempre** valide formato de datas (ISO) e número (sem ponto de milhar).
- ✅ **Sempre** conte itens ANTES de extrair e revalide a contagem ao final.
- ✅ **Sempre** valide `soma de valor_total dos itens ≈ contrato_ata.valor` (diferença ≤ R$ 0,10).
- ✅ **Sempre** preserve a ordem dos itens conforme o documento (item 1 do doc = item 1 do payload).
- ✅ **Sempre** reporte o ID do registro criado ao final.

---

## Padrão de resposta final

Ao concluir o cadastro com sucesso, responda com:

```
✓ <Tipo> cadastrado no SICC.

ID: <id>
Tenant: <tenant_id>
Número: <numero>
<resumo de 1 linha com objeto, valor e fornecedor/contraparte>
```

Ao falhar/parar:
```
✗ Não cadastrei. Motivo: <duplicidade | ambiguidade | dado faltante>
<o que preciso pra continuar, se aplicável>
```
