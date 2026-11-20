# Changelog

## [Não lançado]
- docs: plano do projeto, CLAUDE.md e roadmap
- docs: projeto renomeado para Mynik
- feat(app): cria projeto Xcode multiplataforma (iOS 26 + macOS 26)
- feat(core): adiciona modelos SwiftData Transaction, Category, Account e Bill
- feat(app): adiciona navegação com barra lateral no Mac/iPad e separadores no iPhone
- feat(finance): adiciona lista, criação e edição de gastos e receitas
- feat(today): adiciona tela Hoje com saldo do mês, últimos gastos e contas a vencer
- fix(finance): título do mês sem maiúscula em "de"
- feat(finance): adiciona contas a pagar com recorrência e botão "paguei"
- feat(finance): adiciona notificações de vencimento das contas e ecrã de Definições
- feat(finance): adiciona multi-moeda EUR/BRL com conversão e taxa do BCE
- feat(finance): adiciona orçamento mensal por categoria
- feat(finance): adiciona relatórios com gráficos de gastos por categoria e evolução mensal
- feat(finance): adiciona assinaturas com total mensal e anual
- feat(finance): adiciona importação de extratos CSV do banco com deteção de duplicados
- fix(settings): só pede permissão de notificações quando há contas ou ao ligar o lembrete
- fix(finance): estado vazio de Finanças deixa de tapar os atalhos
- feat(store): adiciona ligação à Shopify (credenciais no Keychain) e cliente GraphQL com limite por custo
- feat(store): adiciona cache SwiftData da loja (produtos, pedidos, estatísticas diárias) com loja de exemplo e migração do esquema
- feat(store): adiciona KPIs (vendas, pedidos, ticket médio, conversão, margem) com comparação, lucro real e gráfico diário
- feat(store): adiciona ranking de produtos com score 0–100, classificação 🟢🟡🟠🔴 e ação sugerida
- feat(store): adiciona diagnóstico do funil (página/preço, checkout/frete ou tráfego) com sugestões
- fix(store): eixo do gráfico diário ajustado aos valores
- fix(app): os testes deixam de abrir a base de dados e as preferências reais da app
- feat(store): adiciona carrinhos abandonados (com link de recuperação) e pedidos por enviar com aviso de atraso
