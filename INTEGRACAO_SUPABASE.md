# 📋 Guia de Integração Supabase - Wampula Vendas

## ✅ O QUE FOI FEITO

### 🔐 Autenticação
- **NÃO FOI ALTERADA** - Mantida intacta conforme solicitado
- Fluxo de login e criação de conta funcionando normalmente

### 📦 Integração Completa Realizada

#### 1. **Produtos (SellerProductService)**
- ✅ CRUD completo integrado com Supabase
- ✅ Busca de produtos por vendedor
- ✅ Busca de produtos ativos para home
- ✅ Atualização de estoque automática
- ✅ Suporte a todas as opções (tamanhos, cores, etc.)
- ✅ Localização da loja

#### 2. **Pedidos (OrderService)**
- ✅ Criação de pedidos do cliente
- ✅ Criação automática de pedidos do vendedor
- ✅ Sincronização de status entre cliente e vendedor
- ✅ Suporte a compra direta e por carrinho
- ✅ Histórico de pedidos

#### 3. **Notificações (NotificationService)**
- ✅ Sistema de notificações automático
- ✅ Notificações criadas via triggers do Supabase
- ✅ Marcar como lida
- ✅ Contar não lidas
- ✅ Deletar notificações

#### 4. **Financeiro (SellerTransactions)**
- ✅ Registro automático de vendas
- ✅ Cálculo de comissão (10%)
- ✅ Saldo disponível e pendente
- ✅ Sistema de saque
- ✅ Estatísticas financeiras

---

## 🗄️ Scripts SQL para Executar no Supabase

Execute os seguintes scripts **NA ORDEM** no SQL Editor do Supabase:

### 1️⃣ Perfis de Usuários (Já existe)
```
📄 supabase_setup.sql
```
Status: ✅ Já deve estar executado

### 2️⃣ Produtos
```
📄 supabase_products_setup.sql
```
Cria:
- Tabela `products`
- RLS policies
- Índices de performance
- View de produtos mais vendidos
- Função de busca por categoria

### 3️⃣ Pedidos
```
📄 supabase_orders_setup.sql
```
Cria:
- Tabela `orders` (pedidos do cliente)
- Tabela `order_items` (itens do pedido)
- Tabela `seller_orders` (pedidos do vendedor)
- ENUMs para status
- Trigger para atualizar estoque automaticamente
- RLS policies
- View de estatísticas

### 4️⃣ Notificações
```
📄 supabase_notifications_setup.sql
```
Cria:
- Tabela `notifications`
- Triggers automáticos para notificar:
  - Cliente quando faz pedido
  - Vendedor quando recebe pedido
  - Cliente quando pedido é entregue
- Funções de contagem e marcação
- RLS policies

### 5️⃣ Transações Financeiras
```
📄 supabase_transactions_setup.sql
```
Cria:
- Tabela `seller_transactions`
- Tabela `seller_balances`
- Trigger para registrar vendas automaticamente
- Função para processar saques
- Função para obter resumo financeiro
- RLS policies

---

## 🚀 Como Executar os Scripts

1. **Acesse o Supabase Dashboard**
   ```
   https://supabase.com/dashboard
   ```

2. **Vá para SQL Editor**
   - Menu lateral > SQL Editor
   - Clique em "New query"

3. **Execute cada script na ordem:**
   
   **Passo 1:** Cole o conteúdo de `supabase_products_setup.sql`
   - Clique em "Run" ou pressione Ctrl+Enter
   - Aguarde confirmação de sucesso
   
   **Passo 2:** Cole o conteúdo de `supabase_orders_setup.sql`
   - Clique em "Run"
   - Aguarde confirmação
   
   **Passo 3:** Cole o conteúdo de `supabase_notifications_setup.sql`
   - Clique em "Run"
   - Aguarde confirmação
   
   **Passo 4:** Cole o conteúdo de `supabase_transactions_setup.sql`
   - Clique em "Run"
   - Aguarde confirmação

4. **Verifique as tabelas criadas**
   - Menu lateral > Table Editor
   - Você deve ver:
     - ✅ products
     - ✅ orders
     - ✅ order_items
     - ✅ seller_orders
     - ✅ notifications
     - ✅ seller_transactions
     - ✅ seller_balances

---

## 🔄 Fluxo de Funcionamento

### Quando um Cliente Compra:

1. **Cliente adiciona produto ao carrinho**
   - Dados ficam em memória (CartService)

2. **Cliente finaliza compra**
   - `OrderService.createOrder()` é chamado
   - Pedido criado em `orders` (Supabase)
   - Itens criados em `order_items`
   - **TRIGGER automático:**
     - Notificação enviada ao cliente
   
3. **Pedido do Vendedor criado automaticamente**
   - `SellerProductService.createOrder()` é chamado
   - Pedido criado em `seller_orders`
   - **TRIGGER automático:**
     - Estoque do produto é atualizado
     - Notificação enviada ao vendedor

### Quando Vendedor Entrega:

1. **Vendedor marca como "Entregue"**
   - Status atualizado em `seller_orders`
   - **TRIGGER automático:**
     - Venda registrada em `seller_transactions`
     - Comissão calculada e registrada (10%)
     - Saldo atualizado em `seller_balances`
     - Status do pedido do cliente atualizado
     - Notificação enviada ao cliente

### Notificações Automáticas:

- ✅ Cliente recebe ao fazer pedido
- ✅ Vendedor recebe ao receber pedido
- ✅ Cliente recebe quando pedido é entregue
- ✅ Tudo via TRIGGERS - sem código manual!

---

## 🔧 Mudanças nos Services

### CartService
- **NÃO FOI ALTERADO**
- Continua funcionando em memória
- Motivo: Carrinho é temporário, não precisa persistir

### SellerProductService
- ✅ Todos os métodos agora são `async`
- ✅ Integração completa com Supabase
- ✅ Conversores JSON adicionados

### OrderService
- ✅ Métodos agora são `async`
- ✅ Criação de pedidos no Supabase
- ✅ Método `loadOrders()` para carregar histórico
- ✅ Conversores JSON adicionados

### NotificationService
- ✅ Métodos agora são `async`
- ✅ Carregamento de notificações do Supabase
- ✅ Marcar como lida
- ✅ Contar não lidas

---

## ⚠️ Pontos de Atenção

### 1. Métodos Async
Antes:
```dart
final products = SellerProductService.getProductModels();
```

Agora:
```dart
final products = await SellerProductService.getProductModels();
```

### 2. Carregar Dados Iniciais
Em telas que exibem pedidos ou notificações, adicione:

```dart
@override
void initState() {
  super.initState();
  _loadData();
}

Future<void> _loadData() async {
  await OrderService().loadOrders();
  await NotificationService.loadNotifications();
  setState(() {});
}
```

### 3. IDs dos Produtos
- Antes: IDs eram strings simples ('1', '2', etc.)
- Agora: IDs são UUIDs do Supabase
- Gerados automaticamente ao criar produto

---

## 🧪 Como Testar

### 1. Teste de Produtos

```dart
// Criar produto
final product = SellerProductModel(
  id: '', // UUID gerado automaticamente
  sellerId: userId,
  sellerStoreName: 'Minha Loja',
  name: 'Produto Teste',
  price: 100.0,
  image: 'url_imagem',
  description: 'Descrição',
  category: 'Eletrônicos',
  stock: 10,
);

await SellerProductService.add(product);

// Buscar produtos
final products = await SellerProductService.getProductModels();
print('Total de produtos: ${products.length}');
```

### 2. Teste de Pedido

```dart
// Fazer pedido
CartService.addProduct(
  product: product,
  quantity: 2,
);

final order = await OrderService().createOrder();
print('Pedido criado: ${order.id}');
```

### 3. Teste de Notificações

```dart
// Carregar notificações
final notifications = await NotificationService.loadNotifications();
print('Total de notificações: ${notifications.length}');

// Contar não lidas
final unread = await NotificationService.countUnread();
print('Não lidas: $unread');
```

---

## 📊 Verificação no Supabase

Após executar os scripts, você pode verificar no SQL Editor:

```sql
-- Ver todos os produtos
SELECT * FROM public.products;

-- Ver pedidos do cliente
SELECT * FROM public.orders;

-- Ver pedidos do vendedor
SELECT * FROM public.seller_orders;

-- Ver notificações
SELECT * FROM public.notifications;

-- Ver transações
SELECT * FROM public.seller_transactions;

-- Ver saldos
SELECT * FROM public.seller_balances;

-- Estatísticas de vendedor
SELECT * FROM public.seller_finance_summary;
```

---

## 🎯 Próximos Passos (Opcional)

1. **Real-time Updates**
   - Adicionar listeners do Supabase para atualizar UI em tempo real
   
2. **Upload de Imagens**
   - Integrar Supabase Storage para imagens de produtos
   
3. **Busca Avançada**
   - Implementar busca full-text no Supabase
   
4. **Cache Local**
   - Adicionar Hive/SharedPreferences para cache offline

---

## 🐛 Troubleshooting

### Erro: "relation does not exist"
- ✅ Execute os scripts SQL na ordem correta
- ✅ Verifique se todas as tabelas foram criadas

### Erro: "RLS policy violation"
- ✅ Verifique se o usuário está autenticado
- ✅ Confira se as policies foram criadas corretamente

### Produtos não aparecem
- ✅ Verifique se `active = true`
- ✅ Verifique se `stock > 0`
- ✅ Use `await` nos métodos async

### Notificações não são criadas
- ✅ Verifique se os triggers foram criados
- ✅ Execute o script de notificações novamente

---

## 📝 Resumo

✅ **4 Scripts SQL criados** - Execute na ordem  
✅ **3 Services integrados** - SellerProduct, Order, Notification  
✅ **Triggers automáticos** - Estoque, transações, notificações  
✅ **RLS habilitado** - Segurança dos dados  
✅ **Autenticação intacta** - Não foi alterada  

**Tudo está pronto para funcionar após executar os scripts SQL!** 🚀
