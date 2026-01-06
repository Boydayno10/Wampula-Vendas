# Instruções Finais - Setup Completo Supabase

## ✅ O que foi corrigido:

### 1. **Home Screen - Carregamento de Produtos**
- ✅ Agora carrega produtos do Supabase automaticamente
- ✅ Se falhar, usa produtos mock como backup
- ✅ Mostra skeleton loader durante carregamento
- ✅ Mostra mensagem quando não há produtos

### 2. **Upload de Imagens - Erro 403**
- ✅ Script SQL criado para criar buckets automaticamente
- ✅ Políticas RLS configuradas corretamente
- ✅ Serviço de upload integrado com Supabase Storage

### 3. **Persistência de Perfil**
- ✅ Método `updateProfile()` salva no Supabase
- ✅ Método `updateStoreInfo()` salva informações da loja
- ✅ Carrega dados completos ao fazer login

## 🚀 Passo a Passo para Funcionar:

### **PASSO 1: Execute o SQL no Supabase**

1. Abra seu projeto no Supabase: https://supabase.com/dashboard
2. Vá em **SQL Editor** (ícone de banco de dados no menu lateral)
3. Clique em **+ New Query**
4. Copie TODO o conteúdo do arquivo `supabase_setup_completo.sql`
5. Cole no editor SQL
6. Clique em **RUN** (ou pressione F5)

⚠️ **IMPORTANTE**: Esse script cria:
- Tabela `profiles` com todos os campos necessários
- 3 buckets do Storage (`product-images`, `profile-images`, `store-banners`)
- 12 políticas RLS para permitir upload de imagens
- Triggers e índices automáticos

### **PASSO 2: Verifique se os buckets foram criados**

1. No Supabase, vá em **Storage** (ícone de pasta no menu)
2. Você deve ver 3 buckets:
   - `product-images` (público)
   - `profile-images` (público)
   - `store-banners` (público)

Se não aparecerem, execute novamente o SQL.

### **PASSO 3: Configure permissões adicionais (se necessário)**

Se ainda der erro 403 ao fazer upload:

1. Vá em **Storage** > Clique em cada bucket
2. Clique em **Policies**
3. Verifique se existem as políticas:
   - "Todos podem ver imagens de [tipo]"
   - "Usuários autenticados podem inserir imagens de [tipo]"
   - "Usuários autenticados podem atualizar imagens de [tipo]"
   - "Usuários autenticados podem deletar imagens de [tipo]"

### **PASSO 4: Configure a URL pública do Storage**

1. Vá em **Settings** > **API**
2. Copie a **URL** do projeto (algo como `https://xxxxx.supabase.co`)
3. Verifique se está configurada corretamente no seu `lib/main.dart`:

```dart
await Supabase.initialize(
  url: 'SUA_URL_AQUI',  // ← Deve ser a URL do projeto
  anonKey: 'SUA_ANON_KEY_AQUI',
);
```

### **PASSO 5: Teste o aplicativo**

1. **Limpe e reconstrua o app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Teste cadastro de produto:**
   - Faça login como vendedor
   - Vá em "Painel do Vendedor"
   - Clique em "+" para adicionar produto
   - Preencha os dados
   - **Selecione uma imagem**
   - Salve
   - ✅ O produto deve aparecer na home

3. **Teste edição de perfil:**
   - Vá em "Perfil"
   - Clique em "Editar Perfil"
   - **Selecione uma foto de perfil**
   - Altere nome/telefone
   - Salve
   - ✅ A foto e dados devem aparecer no perfil

4. **Teste edição da loja:**
   - Vá em "Painel do Vendedor"
   - Clique em "Editar Informações da Loja"
   - **Selecione um banner**
   - Altere nome/descrição
   - Salve
   - ✅ O banner e dados devem aparecer

## 🐛 Solução de Problemas:

### **Erro 403 ao fazer upload:**
- ✅ Execute o SQL `supabase_setup_completo.sql` novamente
- ✅ Verifique se os buckets existem no Storage
- ✅ Verifique se as políticas RLS estão criadas
- ✅ Confirme que o usuário está autenticado (logado)

### **Produtos não aparecem na home:**
- ✅ Execute `flutter clean` e `flutter pub get`
- ✅ Reinicie o app completamente
- ✅ Puxe para baixo na home (pull to refresh)
- ✅ Verifique se o produto foi salvo no Supabase (Table Editor > products)

### **Perfil não salva:**
- ✅ Verifique se a tabela `profiles` existe (Table Editor)
- ✅ Verifique se o usuário está autenticado
- ✅ Confirme que o SQL foi executado corretamente
- ✅ Reinicie o app após fazer login

### **Imagem não aparece após upload:**
- ✅ Verifique se os buckets são PÚBLICOS (public = true)
- ✅ Confirme que a URL retornada é pública
- ✅ Teste acessar a URL diretamente no navegador
- ✅ Verifique se o campo `profile_image_url` foi atualizado na tabela

## 📊 Verificação no Supabase:

### **Table Editor:**

1. **Tabela `profiles`:**
   - Deve ter colunas: `id`, `name`, `email`, `phone`, `bairro`, `is_seller`, `verified`, `profile_image_url`, `store_name`, `store_description`, `store_banner`
   - Após editar perfil, os dados devem aparecer aqui

2. **Tabela `products`:**
   - Deve ter colunas: `id`, `name`, `price`, `category`, `seller_id`, `images`, etc.
   - Após cadastrar produto, deve aparecer aqui
   - A coluna `images` deve ter URLs públicas do Storage

### **Storage:**

1. **Bucket `product-images`:**
   - Após cadastrar produto com imagem, deve aparecer um arquivo aqui
   - Ex: `product_1234567890.jpg`

2. **Bucket `profile-images`:**
   - Após editar perfil com foto, deve aparecer um arquivo aqui
   - Ex: `profile_abc123.jpg`

3. **Bucket `store-banners`:**
   - Após editar loja com banner, deve aparecer um arquivo aqui
   - Ex: `banner_xyz789.jpg`

## ✨ Recursos Funcionando:

✅ Autenticação com Supabase (preservada)
✅ Cadastro de produtos com imagens
✅ Upload de imagens para Storage
✅ Perfil de usuário com foto
✅ Loja de vendedor com banner
✅ Home carrega produtos do Supabase
✅ Persistência de dados no banco
✅ URLs públicas de imagens
✅ RLS para segurança

## 📝 Próximos Passos (Opcional):

Se quiser melhorar ainda mais:

1. **Adicionar compressão de imagens** antes do upload
2. **Limitar tamanho de arquivos** (ex: máximo 5MB)
3. **Mostrar progresso** durante upload
4. **Cachear imagens** para carregar mais rápido
5. **Adicionar crop/edição** de imagens antes do upload

---

**Dúvidas?** Se algo não funcionar, verifique:
1. ✅ SQL foi executado sem erros
2. ✅ Buckets existem no Storage
3. ✅ App foi reconstruído com `flutter clean`
4. ✅ Usuário está autenticado (logado)

Tudo deve funcionar perfeitamente agora! 🎉
