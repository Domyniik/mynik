# Mynik — funcionalidades (checklist de paridade iOS ↔ desktop)

Levantamento feito a partir do código da v1.4 (288 ficheiros Swift, ~28 700 linhas) a 21/11/2026.
É a especificação da versão desktop (Next.js + Tauri): cada `[ ]` passa a `[x]` quando existir no desktop.

- **iOS**: o que a app em Swift faz hoje (fica só no iPhone).
- **Desktop**: como a funcionalidade aparece no `/web` + `/desktop`. Onde a Apple não deixa (Face ID, Foundation Models, EventKit…), está indicada a alternativa grátis.
- As fórmulas da secção 4 são a referência: iOS e desktop têm de dar o mesmo número. As de score, lucro e orçamento passam a funções SQL no Supabase (etapa 2).

---

## 1. Estrutura e navegação

| Secção | Ícone (SF Symbol) | iPhone |
|---|---|---|
| Hoje | sun.max | separador |
| Pergunte ao Mynik | sparkles | Mais |
| Finanças | eurosign.circle | separador |
| Loja | storefront | separador |
| Projetos | checklist | separador |
| Metas | target | Mais |
| Hábitos | flame | Mais |
| Património (investimentos) | chart.line.uptrend.xyaxis | Mais |
| Carro | car | Mais |
| Documentos | person.text.rectangle | Mais |
| Carreira | briefcase | Mais |
| Notas | note.text | Mais |
| Definições | gearshape | Mais |

- [x] Sidebar com as 13 secções (desenho e ordem do mockup: Hoje, Finanças, Loja, Projetos, Notas, Carro, Documentos, Carreira, Património; depois Metas, Hábitos, Pergunte ao Mynik e Definições), utilizador e estado do sync no fundo
- [x] ⌘1–⌘9 abrem as 9 primeiras secções; ⌘, abre Definições
- [x] ⌘K: busca global e ações (ver 3.13)
- [x] ⌘N: novo item no contexto (movimento em Finanças/Hoje, tarefa em Projetos, página em Notas…)
- [x] Modo de demonstração (dados de exemplo, como o `-MynikDemo` do iOS)
- [x] Interface em pt-PT, moeda EUR com BRL, fuso Europe/Madrid, semana a começar à segunda

---

## 2. Dados (modelos SwiftData → tabelas Supabase)

Todos os registos têm `uid` (texto, UUID) como chave estável, exceto os da loja (id da Shopify) e os diários (dia). Relações guardadas como `uid` do outro registo. Hoje vão todos para a tabela genérica `records` (payload JSON, datas em segundos desde 1/1/2001); a etapa 2 cria uma tabela por modelo.

| Modelo | Campos | Relações |
|---|---|---|
| Category | name, symbolName, colorName (12 cores), kindRaw (expense/income), sortOrder, monthlyBudget | → transações, contas a pagar, metas |
| Account | name, typeRaw (checking/savings/card/cash), currencyCode, initialBalance, isArchived, createdAt | saldo = inicial + Σ movimentos com sinal |
| FinanceTransaction | title, amount, kindRaw, currencyCode, date, notes, createdAt, externalID (automáticos) | category, account, linkedNotes (n:m) |
| Bill | title, amount, currencyCode, dueDate, isPaid, paidAt, recurrenceRaw (none/weekly/monthly/yearly), notes, isSubscription, createdAt | category, account |
| StoreProduct | shopifyID, title, handle, statusRaw, imageURL, price, unitCost, unitCostIsManual, inventory, tracksInventory, createdAt, adSpend30d, decisionRaw (scale/keep/discontinue), decidedAt, decisionNote, syncedAt | — |
| StoreOrder | shopifyID, name, createdAt, cancelledAt, subtotal, shipping, tax, total, refunded, currencyCode, financialStatus, fulfillmentStatus, lines[] (productID, title, quantity, currentQuantity, unitPrice), syncedAt | — |
| StoreCheckout | shopifyID, name, createdAt, total, recoveryURL, lines[] (productID, title, quantity), syncedAt | — |
| DailyStat | date, sales, netRevenue, orders, units, refunds, sessions, cartSessions, checkoutSessions, completedSessions, hasTraffic | chave = dia |
| Project | name, details, symbolName, colorName, statusRaw (active/paused/done), dueDate, createdAt | → tarefas (cascata), linkedNotes |
| ProjectTask | title, notes, statusRaw (todo/doing/done), priorityRaw (0/1/2), dueDate, completedAt, createdAt | project (opcional = tarefa avulsa) |
| Goal | title, targetAmount, currencyCode, deadline, symbolName, colorName, sourceRaw (manual/account/category), manualAmount, startDate, isArchived, createdAt | account, category |
| Habit | name, symbolName, colorName, targetPerWeek (1–7), sortOrder, isArchived, createdAt | → checks (cascata) |
| HabitCheck | day, createdAt | habit |
| Note | title, icon (emoji), createdAt, updatedAt, sortOrder, isFavorite, coverRaw (8 capas), isTemplate, isDatabase, databaseSchemaJSON, databaseViewRaw (table/board/calendar), propertyValuesJSON | parent (árvore), → blocks (cascata), linkedProjects, linkedTransactions, linkedNotes/backlinks |
| NoteBlock | kindRaw (14 tipos), text, isChecked, imageData, sortOrder, createdAt, emoji, language, detail, isExpanded | note |
| Vehicle | name, plate, fuelTypeRaw (6 tipos), initialOdometer, notes, createdAt | → abastecimentos, manutenções, prazos (cascata) |
| FuelEntry | date, odometer, quantity, totalCost, currencyCode, isFullTank, station, notes, transactionID, createdAt | vehicle |
| MaintenanceRecord | kindRaw (7 tipos), title, date, odometer, cost, currencyCode, workshop, notes, nextDueDate, nextDueOdometer, transactionID, createdAt | vehicle |
| CarDeadline | kindRaw (inspection/insurance/tax/other), title, dueDate, amount, currencyCode, renewalMonths, notes, lastDoneAt, createdAt | vehicle |
| PersonalDocument | title, kindRaw (7 tipos), number, issuer, expiryDate, remindDaysBefore, notes, createdAt | → fotos |
| DocumentPhoto | imageData, sortOrder, createdAt | document — **nunca sai do dispositivo** |
| JobApplication | company, role, appliedAt, statusRaw (6 estados), statusChangedAt, followUpDate, location, link, salary, contact, notes, createdAt | — |
| Course | title, provider, statusRaw (planned/inProgress/completed), progress, completedAt, link, credentialID, expiresAt, notes, createdAt | — |
| Investment | name, ticker, kindRaw (7 tipos), currencyCode, units, investedAmount, unitPrice, priceUpdatedAt, manualValue, isArchived, notes, createdAt | — |
| WealthSnapshot | day, cash, invested, investmentsValue | chave = dia |

- [ ] Todas as 25 entidades existem no desktop, lidas e escritas no Supabase com RLS
- [ ] Categorias iniciais: Alimentação, Casa, Transporte, Carro, Saúde, Lazer, Compras, Assinaturas, Outros (gasto); Salário, Loja, Outras receitas (receita); conta "Conta principal"
- [ ] Definições guardadas por utilizador (hoje estão em `UserDefaults`, não sincronizadas): taxa BRL/EUR e data, custos da loja (taxa %, taxa fixa, envio, anúncios mensais), alertas da loja, lucro→Finanças, folha do Google Ads e totais, meta de poupança, lembretes, província e combustível, vista das tarefas, auto-categorizar

---

## 3. Módulos e ecrãs

### 3.1 Hoje
iOS: cartão de saldo do mês com mini-gráfico, ações rápidas, contas a vencer (7 dias), calendário e lembretes do dia, tarefas de hoje, hábitos, loja hoje, agenda da vida, metas, revisão semanal ao domingo.
- [x] Saudação e data; busca ⌘K e botão "+ Novo gasto" no topo (mockup)
- [x] KPIs em grelha: saldo do mês (vs mês anterior), gastos do mês (% do orçamento), vendas da loja hoje (pedidos, por enviar), a pagar em 7 dias
- [x] Mini-gráfico de gastos acumulados do mês (SpendingTrend)
- [x] Contas a vencer nos próximos 7 dias (com atrasadas) e botão "paguei"
- [x] Gastos por categoria com barra do orçamento (mockup)
- [x] Vendas da loja nos últimos 7 dias, em barras, com variação (mockup)
- [x] Tarefas de hoje (em curso, atrasadas ou com prazo até hoje; até 6 + "mais N")
- [x] Hábitos do dia, a marcar
- [x] Agenda: prazos do carro, documentos a expirar, follow-ups e certificados (LifeAgenda)
- [x] Metas ativas com progresso
- [x] Eventos e lembretes do dia (desktop: calendário por URL iCal, ver 5.6)
- [x] Revisão semanal (ver 4.12), em destaque ao domingo

### 3.2 Finanças
- [x] Lista de movimentos agrupada por mês, com navegação mês anterior/seguinte e resumo (receitas, gastos, saldo)
- [x] Tabela ordenável por data, descrição, categoria, conta, valor (extra desktop)
- [x] Criar/editar/apagar movimento: tipo, descrição, valor, moeda (EUR/BRL), data, categoria, conta, notas; mostra páginas de notas ligadas
- [x] Valor convertido para EUR quando o movimento é em BRL ("≈ 12,30 €")
- [x] Marca "atualizado automaticamente" nos movimentos com `externalID` (loja, carro, investimentos, Apple Pay)
- [x] Sugestão automática de categoria ao escrever a descrição (ver 4.14)
- [x] Contas (Account): criar, editar, arquivar, saldo atual
- [x] Categorias: criar, editar (nome, ícone, cor, tipo, ordem)
- [x] **Contas a pagar**: por pagar / pagas; criar/editar (descrição, valor, moeda, vencimento, repetição, categoria, conta, assinatura, notas); "Paguei" (ver 4.6)
- [x] **Orçamento**: por categoria de gasto; com orçamento (mais apertadas primeiro) e sem orçamento (mais gasto primeiro); editor do limite mensal (0 = sem)
- [x] **Assinaturas**: lista das contas marcadas como assinatura, custo mensal de cada, total por mês e por ano
- [x] **Relatórios**: donut de gastos por categoria do mês; barras de receitas e gastos dos últimos 6 meses
- [x] **Importar CSV**: escolher ficheiro **ou arrastar para a janela** (extra desktop), conta, moeda; pré-visualização com novos / já existentes / linhas ignoradas; categoria sugerida; sem duplicados (ver 4.15)
- [x] **Scanner de faturas**: imagem ou PDF → comerciante, total e data (desktop: OCR com tesseract.js no dispositivo, mesmo parser)

### 3.3 Loja (Shopify — Neloce)
- [x] Cabeçalho com nome da loja, estado do sync e "Atualizar"; dados de exemplo enquanto a loja não está ligada
- [x] Período Hoje / 7 dias / 30 dias, comparado com o período anterior igual
- [x] KPIs: vendas, pedidos, ticket médio, lucro real, conversão, com variação
- [x] Decomposição do lucro real: vendas brutas − IVA − artigos − envio − taxas − anúncios, com margem
- [x] Aviso de produtos vendidos sem custo definido
- [x] Gráfico diário de vendas e lucro dos últimos 30 dias
- [x] **Ranking de produtos** (tabela ordenável, filtros Todos/Vencedores/Promissores/Em teste/Perdedores), score 0–100 com barra, estado, unidades, receita, margem (ver 4.1)
- [x] **Painel de diagnóstico** ao lado do ranking (mockup): funil do produto, "onde o funil quebra", ação sugerida, "Registar decisão"
- [x] Detalhe do produto: últimos 30 dias (unidades, devolvidas, receita, preço, margem, stock, dias de stock), fatores do score com pontos, custo por unidade e anúncios editáveis, "voltar ao custo da Shopify"
- [x] **Ciclo de vida**: produtos por fase (decisão pendente, em teste, a escalar, mantido, descontinuado), decidir, nota, desfazer, avisos de revisão (ver 4.4)
- [x] **Funil da loja**: visitas → carrinho → checkout → compra, período 7/30 dias, diagnóstico e sugestões (ver 4.3)
- [x] **Pedidos por enviar**, com dias à espera e atrasados (> 3 dias)
- [x] **Carrinhos abandonados** (30 dias): valor total, link de recuperação (copiar)
- [x] **Alertas**: dias sem venda, pedidos atrasados, produto parado, stock baixo (ver 4.5)
- [x] Últimos pedidos (com reembolsos)
- [x] Lucro de cada mês lançado nas Finanças (ver 4.7)
- [x] Gasto do Google Ads importado de uma Google Sheet pública (por produto pelo URL final, o resto como anúncios gerais)

### 3.4 Projetos e tarefas
- [x] Projetos por estado (em curso, em pausa, concluídos) com progresso e tarefas abertas
- [x] Criar/editar/apagar projeto (nome, descrição, ícone, cor, estado, prazo)
- [x] Tarefas avulsas (sem projeto)
- [x] Vista **Kanban** com **arrastar e largar** entre colunas (extra desktop) e vista **lista**; preferência guardada
- [x] Tarefa: título, notas, estado, prioridade (baixa/normal/alta), prazo, projeto; mover entre estados; atrasadas marcadas
- [x] Ordenação das colunas (ver 4.11)
- [x] Notas ligadas ao projeto

### 3.5 Metas
- [x] Ativas e arquivadas, total juntado vs alvo total
- [x] Meta: nome, valor-alvo, moeda, prazo, ícone, cor, origem do progresso (manual / saldo de uma conta / movimentos de uma categoria desde uma data)
- [x] Detalhe: progresso, falta, juntar por mês, prazo passado, movimentos que contam
- [x] "Juntar dinheiro": soma ao manual ou cria o movimento na categoria (ver 4.9)

### 3.6 Hábitos
- [x] Lista com marcação do dia, sequência, semana atual vs objetivo e últimos 7 dias
- [x] Criar/editar/arquivar (nome, ícone, cor, objetivo semanal 1–7)
- [x] Resumo "N de M feitos hoje"

### 3.7 Património (investimentos)
- [x] Resumo: dinheiro nas contas, investido, valor atual, ganho e %, património líquido
- [x] Investimentos ativos e arquivados: nome, tipo (ETF, ações, cripto, fundo, depósito, PPR, outro), ticker, moeda, unidades, investido, valor
- [x] Atualizar cotações (Yahoo Finance + câmbio Frankfurter); ao abrir se tiverem mais de 6 h; lista dos tickers que falharam
- [x] "Verificar" o ticker no formulário
- [x] Aportar: soma ao investido e às unidades; opcionalmente lança a saída na categoria "Investimentos" de uma conta
- [x] Evolução do património (gráfico das fotografias diárias)
- [x] Meta de poupança mensal: poupado este mês, taxa de poupança, progresso (ver 4.10)

### 3.8 Carro
- [x] Vários veículos, escolha do atual; criar/editar/apagar (nome, matrícula, combustível, km iniciais, notas)
- [x] Resumo: consumo médio e último (L/100 km ou kWh/100 km), custo por km, km atuais, gráfico do consumo por abastecimento
- [x] Abastecimentos: data, km, quantidade, total, preço/L calculado, depósito atestado, posto; lançar nas Finanças (categoria "Carro")
- [x] Manutenções: tipo (revisão, óleo, pneus, travões, bateria, reparação, outra), data, km, custo, oficina, próxima por data ou por km; lançar nas Finanças
- [x] Prazos ITV / seguro / imposto / outro com valor e repetição; "Feito" lança o valor e passa ao próximo vencimento (ver 4.13)
- [x] Preços de combustível em Espanha por província (API do Ministerio): mais baratos, média, perto de mim (10 km), abrir no mapa

### 3.9 Documentos
- [x] Lista por estado (expirados, a expirar, válidos, sem validade) com "Expira em N dias"
- [x] Documento: tipo (CC/RG, passaporte, TIE/NIE, carta, saúde, seguro, outro), nome, número, emissor, validade, aviso (1/2/3/6 meses antes), notas
- [x] Número escondido (•••• 45Z) e fotos só depois de desbloquear (desktop: PIN/palavra-passe local, ver 5.5)
- [x] Fotos: adicionar (ficheiro ou arrastar), ver, apagar — **só no dispositivo**, nunca no Supabase

### 3.10 Carreira
- [x] Candidaturas: empresa, cargo, data, estado (enviada, entrevistas, proposta, aceite, recusada, sem resposta), follow-up, local, link, salário, contacto, notas
- [x] Filtro por estado; estatísticas (ativas, entrevistas, propostas, taxa de resposta)
- [x] "Follow-up feito" (o próximo daqui a 7 dias); abrir anúncio
- [x] Cursos e certificações: plataforma, estado, progresso, concluído, link, ID da credencial, validade (aviso 60 dias antes)

### 3.11 Notas (estilo wiki)
- [x] Árvore de páginas aninhadas, favoritos, pesquisa, templates
- [x] Página: ícone (emoji), capa (8 gradientes), título, caminho (breadcrumbs clicáveis), subpáginas
- [x] 14 tipos de bloco: texto, título 1–3, lista com marcas, numerada, tarefas, alternar, citação, destaque com emoji, código (linguagem, copiar), tabela simples, divisor, imagem com legenda
- [x] Menu "/" para inserir/transformar blocos; atalhos Markdown ao escrever (`# `, `- `, `1. `, `[] `, `> `, três crases, `---`)
- [x] Teclado: ⇧⌘↑/↓ mover, ⌘D duplicar, ⇧⌘⌫ apagar, ⌥⌘0–8 transformar, ⇧⌘F favorito; reordenar por arrastar
- [x] Bases de dados: propriedades texto, número, seleção, data, caixa; vistas Tabela, Quadro (arrastar entre colunas) e Calendário; linhas = subpáginas
- [x] Menções `@` a páginas, projetos, movimentos e datas; backlinks; `[[Título]]` antigo continua a funcionar
- [x] Ligações a projetos e movimentos (secção "Ligações")
- [x] Templates: Reunião, Diário, Projeto, Leituras, Semana (`{{data}}`) e "Guardar como template"
- [x] Exportar página em Markdown
- [x] Importar export do Notion (ZIP com Markdown e CSV, ZIPs partidos, imagens, bases com tipos inferidos)

### 3.12 Pergunte ao Mynik
iOS: chat com Foundation Models e ferramentas que leem os dados; sem Apple Intelligence responde com resumos.
- [ ] Chat com sugestões de perguntas e "Nova conversa"
- [ ] Respostas a partir dos resumos (QuestionRouter + MynikDataDigest): finanças de um mês, gasto numa categoria/comerciante, contas a pagar, loja por período, carro, documentos, carreira, metas, património, agenda
- [ ] (Opcional, grátis) modelo local via Ollama se estiver instalado; sem ele, o modo de resumos

### 3.13 Busca global (⌘K)
- [ ] Procura em secções, movimentos, contas a pagar, notas (título e texto), projetos, tarefas, metas, hábitos, veículos, documentos (sem números), candidaturas, cursos, investimentos, produtos; máx. 40; ranking da secção 4.16
- [ ] Ações rápidas no ⌘K (novo gasto, nova tarefa, nova página, ir para…)

### 3.14 Definições
- [ ] Conta: entrar por magic link, sessão, último sync, sincronizar agora, terminar sessão
- [ ] Moedas: taxa EUR↔BRL manual ou "atualizar taxa do dia" (Frankfurter)
- [ ] Notificações: contas a pagar (N dias antes), prazos da agenda, revisão semanal ao domingo às 19h
- [ ] Loja Shopify: estado da ligação, testar (no desktop o segredo fica no servidor, ver 5.1)
- [ ] Custos da loja (taxa %, taxa fixa, envio por pedido, anúncios mensais) e "lançar o lucro mensal nas Finanças"
- [ ] Alertas da loja: avisar de cada venda, dias sem venda
- [ ] Google Ads: URL da folha, gasto 30 dias, atualizar
- [ ] Inteligência: sugerir categoria
- [ ] Privacidade: bloqueio da app
- [ ] Cópia de segurança: exportar/importar JSON (mesmo formato do iOS, fusão por `uid`)
- [ ] Iniciar com o sistema (extra desktop)

---

## 4. Cálculos (referência)

Valores em EUR; BRL convertido com a taxa das Definições (por omissão 6,0 BRL por 1 EUR). "Dia" = início do dia no fuso local.

### 4.1 Score dos produtos (0–100)
Base: produtos **ativos**, janela de 30 dias (`windowStart = hoje − 29 dias`), pedidos não cancelados.
- `units` = Σ currentQuantity; `orderedUnits` = Σ quantity; `refundedUnits` = Σ max(0, quantity − currentQuantity); `revenue` = Σ unitPrice × currentQuantity.
- `daysSinceLastSale`: última venda em toda a cache (pode ser anterior à janela); `nil` sem vendas.
- `ageDays` = dias desde `createdAt`; `adSpend` = adSpend30d.
- `abandonedUnits`: unidades em checkouts abandonados dos últimos 30 dias (`nil` se não há checkouts em cache).

| Fator | Máx. | Pontos |
|---|---|---|
| Vendas | 20 | 20 × clamp(units / maior `units` entre os produtos) |
| Receita | 15 | 15 × clamp((revenue / receita total) / 0,25) |
| Margem | 20 | com custo: 20 × clamp((margem − 0,2) / 0,5), margem = (preço − custo) / preço; sem custo: 12 (neutro) |
| Funil | 10 | conversão = orderedUnits / (orderedUnits + abandonedUnits) se ≥ 5 unidades: 10 × clamp((conv − 0,3) / 0,5); senão 6 |
| Reembolsos | 10 | 10 × (1 − clamp(refundRate / 0,2)) |
| Recência | 15 | sem vendas 0; senão 15 × (1 − clamp((dias − 3) / 27)) |
| ROAS | 10 | com anúncios: 10 × clamp((revenue/adSpend − 1) / 3); sem anúncios 7 |

`score` = arredondamento da soma. Ordenar por score desc, depois título.

**Classificação:** `ageDays < 14` → Em teste; `orderedUnits < 3 e ageDays < 30` → Em teste; `score ≥ 70` → Vencedor; `≥ 45` → Promissor; senão Perdedor.

**Ação sugerida:**
- Vencedor: dias de stock < 14 → "Repor stock: ao ritmo atual só dá para N dias."; ROAS ≥ 3 → "Escalar: aumentar o orçamento de anúncios."; senão "Escalar: testar anúncios e novos criativos."
- Promissor: pelo fator com dados de menor rácio — margem "Rever o preço ou o fornecedor para subir a margem."; funil "Melhorar a página do produto: fotos, descrição e avaliações."; reembolsos "Perceber o motivo das devoluções (qualidade, tamanho, descrição)."; ROAS "Ajustar os anúncios: público ou criativo."; recência "Reativar com uma promoção ou um e-mail."; vendas/receita "Dar mais visibilidade: destaque na loja e anúncios."
- Em teste: faltam N dias → "Manter o teste mais N dias antes de decidir."; senão "Juntar mais dados (vendas ou anúncios) antes de decidir."
- Perdedor: com anúncios → "Pausar os anúncios e tirar de destaque."; ≥ 30 dias sem venda → "Arquivar ou escoar o stock com desconto."; senão "Rever a oferta (preço, fotos) ou descontinuar."

`daysOfStock` = floor(max(0, inventory) / (units / 30)), só se conta stock e units > 0.

### 4.2 Lucro real da loja
Para os pedidos não cancelados de um período com `d` dias:
- vendas brutas = Σ total; IVA = Σ tax; receita líquida = brutas − IVA
- taxas = Σ (total × taxa% / 100 + taxa fixa), só se total > 0 (omissão 2,1 % + 0,25 €)
- envio = custo de envio (omissão 4 €) por pedido com unidades
- artigos = Σ custo unitário do produto × currentQuantity
- anúncios = (Σ adSpend30d dos produtos + anúncios mensais + Google Ads sem produto) / 30 × d
- **lucro = receita líquida − artigos − envio − taxas − anúncios**; margem = lucro / receita líquida
- KPIs: pedidos, unidades, ticket médio = brutas / pedidos, conversão = completedSessions / sessions (só com tráfego); variação = (atual − anterior) / |anterior|
- Períodos: Hoje (1 dia), 7, 30 dias a acabar hoje; o anterior tem o mesmo número de dias

### 4.3 Funil da loja
Etapas visitas → carrinho (bom ≥ 6 %, fraco < 4 %) → checkout (bom ≥ 50 %, fraco < 35 %) → compra (bom ≥ 50 %, fraco < 35 %), cada taxa face à etapa anterior.
Diagnóstico: sem tráfego → "Sem dados de tráfego"; < 100 visitas → "Poucos dados"; etapa fraca com menor taxa/limite → Carrinho = "Página ou preço", outras = "Checkout ou frete"; < 50 visitas/dia → "Tráfego"; senão "Funil saudável". Cada um com explicação e sugestões fixas.

### 4.4 Ciclo de vida do produto
Decidido → a decisão; `ageDays < 14` → Em teste (faltam 14 − idade); senão Decisão pendente com sugestão (Vencedor → Escalar, Promissor → Manter, Perdedor → Descontinuar, Em teste → prolongar). Ordem: pendente, teste, a escalar, mantido, descontinuado.
Avisos: escalar + perdedor; manter + perdedor; descontinuar + vencedor; descontinuado mas ativo na Shopify.

### 4.5 Alertas da loja
- dias sem venda ≥ N (omissão 3) → alerta; crítico se ≥ 2N
- pedidos atrasados: por enviar há > 3 dias (estados UNFULFILLED, PARTIALLY_FULFILLED, IN_PROGRESS, OPEN, PENDING_FULFILLMENT, ON_HOLD, REQUEST_DECLINED; não cancelado, com unidades, não REFUNDED)
- produto parado: ≥ 14 dias de idade e ≥ 14 dias sem venda
- stock baixo: dias de stock < 7 (crítico < 3)
- Notificações: cada venda nova (máx. 3 de cada vez, sem repetir) e "dias sem venda" uma vez por dia

### 4.6 Contas a pagar — "Paguei"
Cria o gasto (descrição, valor, moeda, categoria, conta da conta a pagar) na data do pagamento; `paidAt` = data. Se se repete: `dueDate` avança uma semana/mês/ano e continua por pagar; senão fica paga.
Lembretes: um aviso N dias antes e outro no dia, à hora definida, só no futuro (máx. 60).

### 4.7 Lucro da loja → Finanças
Um movimento por mês (`externalID = store-profit-AAAA-MM`), para o mês anterior e o atual se a cache os cobre por inteiro. Lucro ≥ 0 → receita "Lucro da loja · mês" na categoria Loja; prejuízo → gasto "Prejuízo da loja · mês" sem categoria. Valor arredondado a 2 casas; data = fim do mês ou hoje; notas com vendas, pedidos e margem.

### 4.8 Orçamento
Por categoria de gasto, no mês: gasto = Σ movimentos de gasto da categoria em EUR. Com orçamento: restante = orçamento − gasto, progresso = gasto / orçamento, excedido se gasto > orçamento. Totais = Σ das categorias com orçamento.
Mês: receitas, gastos e saldo = receitas − gastos (todas as moedas em EUR). Relatórios: gastos por categoria (sem categoria = "Sem categoria") e totais dos últimos 6 meses. Assinaturas: semanal × 52 / 12, mensal × 1, anual / 12; total anual = mensal × 12.

### 4.9 Metas
Juntado: manual = valor manual; conta = saldo da conta convertido para a moeda da meta; categoria = Σ movimentos do mesmo tipo da categoria desde `startDate`.
Fração = clamp(juntado / alvo); falta = max(0, alvo − juntado); meses até ao prazo = max(1, meses + (dias > 0 ? 1 : 0)); por mês = falta / meses (2 casas); prazo passado se antes de hoje.

### 4.10 Património e poupança
Dinheiro = Σ saldos das contas não arquivadas; investido = Σ investedAmount; valor = unidades × cotação se tem ticker e cotação, senão valor manual; ganho = valor − investido. Fotografia diária (WealthSnapshot) ao abrir.
Poupado no mês = receitas − gastos + aportes (gastos na categoria "Investimentos"); taxa = poupado / receitas; progresso = poupado / meta.

### 4.11 Tarefas
Coluna: prioridade alta primeiro, depois prazo mais próximo (sem prazo no fim), depois as mais antigas; "Feito" pelas concluídas mais recentes. Hoje: em curso, ou por fazer com prazo até ao fim de hoje. Atrasada: por fazer com prazo antes de hoje. Progresso do projeto = feitas / total.

### 4.12 Revisão semanal (segunda a domingo)
Gastos, receitas, variação dos gastos face à semana anterior, 3 categorias com mais gasto, contas pagas esta semana, contas da próxima semana (n.º e total), tarefas concluídas, hábitos no objetivo, vendas e pedidos da loja.

### 4.13 Carro
Consumo pelo método do depósito cheio: entre dois atestos soma-se o que se meteu depois do primeiro (incluindo parciais) e divide-se pelos km; média = Σ quantidade / Σ km × 100; custo/km = Σ custo / Σ km. Km atuais = máximo entre km iniciais, abastecimentos e manutenções. Prazo "Feito": lança o valor nas Finanças e o próximo vencimento = data + renovação (ITV conta a partir da data em que foi feita; os outros a partir do vencimento). Agenda: prazos avisam 30/7/0 dias antes; manutenção pela data (14 dias, avisos 7/0) ou pelos km (faltam ≤ 1000 km).

### 4.14 Categoria automática
1) o mesmo comerciante nos últimos 500 movimentos categorizados do mesmo tipo; 2) (iOS) Foundation Models só entre as categorias existentes; 3) regras por comerciante e palavras (MerchantCategoryRules). Desktop: 1 e 3.

### 4.15 Importação CSV
Separador `;`, `,` ou tab (o mais frequente na 1.ª linha), aspas respeitadas; cabeçalho procurado nas primeiras linhas em pt/es/en (Data/Fecha/Date, Descrição/Concepto, Valor/Importe, Débito/Crédito); valores "1.234,56", "1,234.56", "(12,30)", "12,30 €"; positivo = receita, negativo = gasto. Duplicado = mesmo dia, valor e descrição.

### 4.16 Busca
Começa por = 0, uma palavra começa por = 1, contém = 2; campos secundários +3; sem acentos nem maiúsculas; mínimo 2 caracteres.

### 4.17 Outros
- Hábitos: sequência conta até hoje (ou até ontem se hoje não está marcado); semana de segunda a domingo.
- Documentos: "a expirar" quando faltam ≤ dias de aviso; textos "Expira hoje/amanhã/em N dias", "Expirou há N dias", "Válido até…".
- Carreira: taxa de resposta = respondidas / total (respondida = estado que não é enviada nem sem resposta); follow-up sugerido = +7 dias.
- Valores de texto ("12,50 €", "R$ 10,00", "1.234,56") → valor e moeda (AmountTextParser).

---

## 5. Integrações e plataforma

| # | iOS | Desktop |
|---|---|---|
| 5.1 | Shopify Admin GraphQL (só leitura, client credentials, segredos no Keychain), limite por custo, cache de 120 dias, sync a cada 15 min e em segundo plano | Só no servidor, segredos em variáveis de ambiente; mesmas queries (produtos, pedidos de 60 dias, checkouts abandonados, tráfego por ShopifyQL); cache em tabelas Supabase partilhadas com o iPhone |
| 5.2 | Supabase: login por email/link (`mynik://login`), sync local-first por `records` | Mesmo projeto e login (magic link); tabelas tipadas com RLS e Realtime |
| 5.3 | Frankfurter (BRL/EUR e câmbio das cotações), Yahoo Finance (cotações), Ministerio (combustível), Google Sheets CSV (Google Ads) | As mesmas APIs grátis, chamadas pelo servidor (sem CORS) |
| 5.4 | Notificações locais: contas, agenda, revisão semanal, venda, dias sem venda | Notificações nativas do Tauri (contas a vencer, venda nova, prazos) |
| 5.5 | Face ID para abrir a app e para os documentos | PIN ou palavra-passe local para abrir e para os documentos (o Touch ID não está disponível no Tauri desktop) |
| 5.6 | EventKit: eventos e lembretes de hoje | URL iCal do calendário (iCloud ou Google, grátis), só leitura |
| 5.7 | Widgets (saldo do mês, contas a vencer) e Live Activity | Ícone na tray: gasto rápido e vendas de hoje |
| 5.8 | App Intents / Siri / Atalhos ("gastei X em Y"), automação Apple Pay | ⌘K e atalho global para o ⌘K (fica só no iPhone a parte Siri/Apple Pay) |
| 5.9 | Foundation Models (categoria, chat) | Regras e resumos; Ollama local opcional |
| 5.10 | VisionKit + Vision OCR | tesseract.js no dispositivo |
| 5.11 | Backup JSON por AirDrop/Ficheiros | Exportar/importar o mesmo JSON |
| 5.12 | MenuBarExtra no Mac (saldo, contas a 7 dias, gasto rápido) | Tray do Tauri |

- [x] 5.1 Shopify no servidor
- [ ] 5.2 Login e dados no Supabase
- [x] 5.3 APIs grátis
- [ ] 5.4 Notificações nativas
- [ ] 5.5 Bloqueio da app e dos documentos
- [x] 5.6 Calendário por iCal
- [ ] 5.7 Tray com vendas de hoje
- [ ] 5.8 Atalho global para o ⌘K
- [ ] 5.9 IA sem Apple (regras e resumos)
- [ ] 5.10 OCR de faturas
- [ ] 5.11 Backup JSON
- [ ] 5.12 Tray com gasto rápido
- [ ] Iniciar com o sistema
- [ ] Instaladores: .dmg (Apple Silicon e Intel) e .exe (Windows) nas GitHub Releases

---

## 6. Só no Mac em Swift (sai na etapa 1)

- `Features/MenuBar/MenuBarContentView.swift` e `Features/Settings/MenuBarSettingsSection.swift`, `SettingsKey.showMenuBarExtra`
- Blocos `#if os(macOS)` em 26 ficheiros (`MynikApp`, `RootView`, formulários, `GlobalSearchView`, `BackupService`, `Clipboard`, `TodayView`, `SettingsView`, …) e nos testes `NotionImportTests` e `ShopifyClientTests`
- `project.yml`: `supportedDestinations: [iOS, macOS]` nos 3 targets, `MYNIK_APP_GROUP[sdk=macosx*]`, assinatura manual do Mac, `TEST_HOST[sdk=macosx*]`, `ENABLE_APP_SANDBOX`/`HARDENED_RUNTIME`/`USER_SELECTED_FILES` (só macOS), widgets do Mac
- Ícones do Mac em `AppIcon.appiconset` (`AppIcon-mac-*`) — passam para o ícone do Tauri
- Atualização da loja de 15 em 15 min no Mac (`StoreBackgroundRefresh`)
- `scripts/release.sh` (compila o Mac e atualiza a cask)

---

## 7. Diferenças em relação ao mockup

- O mockup mostra **Vistas** e **Carrinho** por produto e o funil "vistas → carrinho → compra" por produto. Hoje a app só tem o funil da loja inteira (sessões do ShopifyQL) e, por produto, a conversão checkout → compra. Para ter vistas e carrinho por produto é preciso uma query ShopifyQL por produto (`read_reports`); fica proposta para a etapa 3, com o funil por produto a usar o que houver.
- O mockup tem o período **90 dias** na Loja; a app tem Hoje / 7 / 30 dias. Proposta: acrescentar 90 dias no desktop e no iOS só se a cache passar de 120 para pelo menos 180 dias.
- A sidebar do mockup tem 9 secções; o desktop terá as 13 (as 4 em falta: Pergunte ao Mynik, Metas, Hábitos, Definições).
