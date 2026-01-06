# Módulo Seller - Documentação Completa

## 📋 Visão Geral

O módulo Seller (Vendedor) foi completamente implementado no projeto Wampula Vendas, permitindo que usuários cadastrem e gerenciem produtos, acompanhem pedidos e controlem suas finanças de forma integrada com o restante da aplicação.

## 🏗️ Arquitetura Implementada

### 📁 Estrutura de Arquivos

```
lib/
├── models/
│   ├── seller_product_model.dart       # Modelo de produto do vendedor
│   ├── seller_order_model.dart         # Modelo de pedidos do vendedor
│   └── seller_finance_model.dart       # Modelos financeiros (transações e resumo)
│
├── services/
│   └── seller_product_service.dart     # Serviço com toda lógica de negócio
│
├── screens/seller/
│   ├── seller_dashboard.dart           # Dashboard principal com visão geral
│   ├── seller_products_screen.dart     # Lista de produtos com filtros
│   ├── seller_product_form.dart        # Formulário de cadastro/edição
│   ├── seller_orders_screen.dart       # Gerenciamento de pedidos
│   └── seller_finance_screen.dart      # Controle financeiro e saques
│
└── data/
    └── mock_products.dart              # Integrado com produtos do seller
```

## 🎯 Funcionalidades Implementadas

### 1. **Gerenciamento de Produtos (CRUD Completo)**

#### ✅ Criar Produto
- Formulário completo com validação
- Campos: Nome, Categoria, Preço, Estoque, Descrição
- Toggle de ativo/inativo
- Categorias predefinidas (Eletrónicos, Família, Alimentos, Beleza, etc.)

#### ✅ Listar Produtos
- Lista visual com imagens
- Filtros: Todos, Ativos, Inativos
- Busca por nome e categoria
- Indicadores de estoque e status
- Pull-to-refresh

#### ✅ Editar Produto
- Atualização de todos os campos
- Histórico de alterações (data de atualização)
- Validação de dados

#### ✅ Excluir Produto
- Confirmação antes de excluir
- Feedback visual

#### ✅ Ativar/Desativar Produto
- Toggle rápido para visibilidade
- Produtos inativos não aparecem na Home

### 2. **Gerenciamento de Pedidos**

#### 📦 Lista de Pedidos
- Visualização de todos os pedidos recebidos
- Filtros por status: Novo, Processando, Enviado, Entregue, Cancelado
- Informações: Cliente, produto, quantidade, valor, data
- Cores e ícones indicativos de status

#### 📋 Detalhes do Pedido
- Modal completo com todas as informações
- Dados do cliente (nome, telefone, endereço)
- Detalhes do produto
- Valores (subtotal, comissão, valor líquido)
- Histórico de datas (criado, processado, entregue)

#### 🔄 Atualização de Status
- Fluxo: Novo → Processando → Enviado → Entregue
- Opção de cancelamento
- Feedback visual e confirmação
- Registro automático na parte financeira ao entregar

### 3. **Controle Financeiro**

#### 💰 Resumo Financeiro
- **Saldo Disponível**: Valor pronto para saque
- **Vendas Totais**: Soma de todas as vendas
- **Comissões**: 10% retido pela plataforma
- **Receita Líquida**: Vendas - Comissões
- **Saldo Pendente**: Pedidos não entregues

#### 📊 Estatísticas
- Total de pedidos
- Pedidos entregues
- Visualização clara de receitas e despesas

#### 💳 Extrato de Transações
- Lista completa de movimentações
- Tipos: Venda, Comissão, Saque, Reembolso
- Data e hora de cada transação
- Valores com indicação de crédito/débito
- Vinculação com pedidos

#### 🏦 Solicitação de Saque
- Validação de saldo disponível
- Formulário de valor a sacar
- Informações de prazo (2 dias úteis)
- Registro da transação

### 4. **Dashboard do Vendedor**

#### 📈 Visão Geral
- Card de boas-vindas personalizado
- Estatísticas em cards visuais:
  - Quantidade de produtos
  - Total de pedidos
  - Pedidos entregues
  - Saldo disponível

#### 💼 Resumo Financeiro
- Vendas totais
- Comissões pagas
- Receita líquida
- Saldo pendente (se houver)

#### 🚀 Acesso Rápido
- Cards grandes para navegação
- Informações contextuais em cada card
- Navegação intuitiva para:
  - Meus Produtos
  - Pedidos
  - Finanças

## 🔗 Integração com a Home

### Como Funciona

1. **Conversão Automática**: Produtos do vendedor são convertidos para `ProductModel`
2. **Mesclagem de Dados**: `mockProducts` agora retorna produtos estáticos + produtos dos vendedores
3. **Visibilidade**: Apenas produtos ativos com estoque > 0 aparecem
4. **Funcionalidades**: Produtos do seller funcionam igual aos mockados:
   - Aparecem nas categorias
   - Podem ser adicionados ao carrinho
   - Participam da busca
   - Podem aparecer nos banners em destaque

### Implementação Técnica

```dart
// Em mock_products.dart
List<ProductModel> get mockProducts {
  final staticProducts = _staticMockProducts;
  final sellerProducts = SellerProductService.getProductModels();
  return [...staticProducts, ...sellerProducts];
}
```

## 🛠️ Serviço Principal (SellerProductService)

### Métodos Implementados

#### Produtos
- `add(product)` - Adicionar novo produto
- `update(product)` - Atualizar produto existente
- `remove(id)` - Remover produto
- `bySeller(sellerId)` - Listar produtos do vendedor
- `getById(id)` - Buscar produto por ID
- `getProductModels()` - Converter para exibição na Home

#### Pedidos
- `getOrdersBySeller(sellerId)` - Listar pedidos
- `updateOrderStatus(orderId, status)` - Atualizar status
- `createMockOrder(...)` - Criar pedido de teste

#### Finanças
- `getTransactionsBySeller(sellerId)` - Extrato
- `getFinanceSummary(sellerId)` - Resumo financeiro
- `requestWithdrawal(sellerId, amount)` - Solicitar saque

#### Mock Data
- `initializeMockData(sellerId)` - Inicializar dados de exemplo

## 📱 UX/UI

### Design System Implementado

- **Cores Consistentes**: Deep Purple como cor principal
- **Cards Elevados**: Material Design 3
- **Ícones Informativos**: Contextualizados para cada ação
- **Feedback Visual**: SnackBars, Loading states, Empty states
- **Responsivo**: Adapta a diferentes tamanhos de tela
- **Pull-to-Refresh**: Em todas as listas
- **Validação**: Formulários com validação em tempo real

### Estados da Interface

- ✅ **Loading**: Indicadores durante operações assíncronas
- ✅ **Empty State**: Mensagens quando não há dados
- ✅ **Success**: Confirmações de ações bem-sucedidas
- ✅ **Error**: Tratamento de erros com mensagens claras

## 🎮 Como Usar

### Acessar o Módulo Seller

1. Abra o app
2. Navegue para a aba "Perfil"
3. Toque em "Mudar para vendedor"
4. Dashboard do vendedor será aberto

### Cadastrar Produto

1. No Dashboard → "Meus Produtos"
2. Toque no botão "Novo Produto"
3. Preencha os campos obrigatórios
4. Toque em "Cadastrar Produto"
5. Produto aparecerá na Home automaticamente (se ativo e com estoque)

### Gerenciar Pedidos

1. No Dashboard → "Pedidos"
2. Veja lista de pedidos com status
3. Toque em um pedido para ver detalhes
4. Use os botões para atualizar status:
   - "Iniciar Processamento" (Novo → Processando)
   - "Marcar como Enviado" (Processando → Enviado)
   - "Confirmar Entrega" (Enviado → Entregue)

### Controlar Finanças

1. No Dashboard → "Finanças"
2. Veja saldo disponível no topo
3. Role para ver extrato de transações
4. Para sacar: Toque em "Solicitar Saque"

## 🧪 Dados Mockados de Teste

Ao acessar o Dashboard pela primeira vez, são criados automaticamente:

- **2 produtos de exemplo**
  - Produto Demo 1 (Eletrónicos) - 1500 MT
  - Produto Demo 2 (Família) - 850 MT

- **5 pedidos de exemplo** com diferentes status
  - 1 Novo
  - 1 Processando
  - 1 Enviado
  - 1 Entregue
  - 1 variável

- **Transações financeiras** do pedido entregue

## 🔄 Fluxo Completo de Venda

```
1. Vendedor cadastra produto
   ↓
2. Produto aparece na Home (se ativo e com estoque)
   ↓
3. Cliente compra produto
   ↓
4. Pedido criado (Status: Novo)
   ↓
5. Vendedor processa (Status: Processando)
   ↓
6. Vendedor envia (Status: Enviado)
   ↓
7. Vendedor confirma entrega (Status: Entregue)
   ↓
8. Sistema registra:
   - Transação de venda (+total)
   - Transação de comissão (-10%)
   - Atualiza saldo disponível
   - Atualiza estoque do produto
   - Incrementa contador de vendas
```

## ⚙️ Configurações e Regras de Negócio

### Comissão da Plataforma
- **Taxa**: 10% sobre cada venda
- **Quando é cobrada**: Na confirmação da entrega
- **Cálculo**: Valor do pedido × 0.10

### Saldo e Saques
- **Saldo Disponível**: Vendas entregues - Comissões - Saques
- **Saldo Pendente**: Pedidos não entregues (90% após comissão)
- **Prazo de Saque**: 2 dias úteis (informativo)

### Visibilidade de Produtos
- Produto deve estar **ativo** (active = true)
- Produto deve ter **estoque > 0**
- Categoria deve ser válida

## 🚀 Próximas Melhorias (Sugestões)

1. **Upload de Imagens**: Integrar com câmera/galeria
2. **Notificações Push**: Alertar vendedor sobre novos pedidos
3. **Relatórios**: Gráficos de vendas por período
4. **Múltiplas Imagens**: Galeria de fotos por produto
5. **Variações**: Cores, tamanhos, etc.
6. **Chat**: Comunicação vendedor-cliente
7. **Avaliações**: Sistema de reviews
8. **Backend Real**: Firebase ou API REST
9. **Autenticação**: Login real de vendedores
10. **Dashboard Analytics**: Métricas avançadas

## 🐛 Notas Importantes

- Todos os dados são mockados (simulados)
- Não há persistência real (dados resetam ao reiniciar o app)
- Autenticação é simulada (sempre usa mesmo usuário)
- Imagens usam placeholder padrão
- A integração está pronta para backend futuro

## ✅ Checklist de Implementação

- [x] Modelos de dados (Product, Order, Finance)
- [x] Serviço completo com CRUD
- [x] Dashboard com estatísticas
- [x] Tela de produtos (lista, filtros, busca)
- [x] Formulário de produto (criar/editar)
- [x] Tela de pedidos (lista, detalhes, status)
- [x] Tela financeira (resumo, extrato, saque)
- [x] Integração com Home do app
- [x] Dados mockados para testes
- [x] UI/UX consistente e responsiva
- [x] Validações e feedback visual
- [x] Estados vazios e loading
- [x] Documentação completa

## 🎉 Conclusão

O módulo Seller está **100% funcional e integrado** com o restante da aplicação. Vendedores podem gerenciar produtos, pedidos e finanças de forma completa, e os produtos cadastrados aparecem automaticamente na Home para todos os usuários.

A arquitetura foi desenvolvida de forma modular e escalável, facilitando futuras integrações com backend real e adição de novas funcionalidades.

---
**Desenvolvido para Wampula Vendas** - Dezembro 2025
