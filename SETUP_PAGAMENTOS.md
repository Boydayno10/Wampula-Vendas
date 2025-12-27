# 🔧 SETUP DE NÚMEROS DE PAGAMENTO NO SUPABASE

## 📋 Instruções de Configuração

### 1️⃣ Executar o Script SQL no Supabase

1. Acesse o **Supabase Dashboard**
2. Vá para **SQL Editor**
3. Abra o arquivo `supabase_payment_numbers_setup.sql`
4. **Copie todo o conteúdo** e **cole no SQL Editor**
5. Clique em **RUN** para executar

### 2️⃣ O que foi criado

O script cria:

✅ **Tabela `payment_numbers`** com os seguintes campos:
- `id` - ID único do registro
- `user_id` - ID do usuário (referência para auth.users)
- `number` - Número de telefone M-Pesa
- `is_primary` - Se é o número principal do usuário
- `created_at` - Data de criação
- `updated_at` - Data de atualização

✅ **Índices** para melhor performance de consultas

✅ **RLS (Row Level Security)** com políticas:
- Usuários só podem ver seus próprios números
- Usuários podem adicionar, editar e remover seus números
- Ninguém pode acessar números de outros usuários

✅ **Triggers automáticos**:
- Atualização automática do campo `updated_at`
- Garantia de que apenas um número seja marcado como principal por usuário

### 3️⃣ Como funciona na aplicação

#### Carregar números ao iniciar a tela
```dart
await PaymentService.loadPaymentNumbers();
```

#### Adicionar novo número
```dart
await PaymentService.addNumber('841234567');
```

#### Definir número como principal
```dart
await PaymentService.setPrimary(numberId);
```

#### Remover número
```dart
await PaymentService.remove(numberId);
```

### 4️⃣ Fluxo de uso

1. **Usuário acessa Pagamentos** → Sistema carrega números salvos
2. **Adiciona novo número** → Salvo no Supabase
3. **Define como principal** → Atualizado no Supabase
4. **Remove número** → Deletado do Supabase
5. **Faz checkout** → Usa o número principal automaticamente

### 5️⃣ Segurança

- ✅ Cada usuário só vê seus próprios números
- ✅ Números são vinculados ao usuário autenticado
- ✅ RLS protege contra acesso não autorizado
- ✅ Validação automática de número principal único

### 6️⃣ Verificar se funcionou

Execute no SQL Editor:
```sql
SELECT * FROM payment_numbers;
```

Você deve ver a tabela criada com as políticas RLS ativas.

## 🔄 Sincronização

Os números são:
- **Carregados** ao abrir a tela de pagamentos
- **Sincronizados** automaticamente ao adicionar/editar/remover
- **Persistidos** no Supabase para uso em qualquer dispositivo

## ⚠️ Importante

Certifique-se de que:
1. O usuário está autenticado antes de usar PaymentService
2. A conexão com Supabase está configurada corretamente
3. As políticas RLS estão ativas (segurança)
