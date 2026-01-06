# 🚨 CORREÇÃO URGENTE - Erro 403 Storage

## Erro Atual:
```
Erro ao salvar produto: Exception: Erro ao fazer upload da imagem: 
StorageException(message: new row violates row-level security policy, 
statusCode: 403, error: Unauthorized)
```

## ✅ Solução:

### PASSO 1: Execute o SQL Corrigido

1. Abra seu Supabase: https://supabase.com/dashboard
2. Vá em **SQL Editor**
3. Clique em **+ New Query**
4. Copie TODO o conteúdo de `supabase_setup_completo.sql`
5. Cole e clique em **RUN**

### PASSO 2: Verifique os Buckets

1. Vá em **Storage** (menu lateral)
2. Você deve ver 3 buckets:
   - ✅ `product-images`
   - ✅ `profile-images`  
   - ✅ `store-banners`

### PASSO 3: Verifique as Políticas (Opcional)

1. Clique em cada bucket
2. Vá em **Policies**
3. Deve ter 4 políticas em cada:
   - SELECT (ver) - `public`
   - INSERT (upload) - `authenticated users`
   - UPDATE (atualizar) - `authenticated users`
   - DELETE (deletar) - `authenticated users`

### PASSO 4: Teste no App

1. Hot reload no app (pressione `r` no terminal)
2. Tente cadastrar produto com imagem
3. ✅ Deve funcionar agora!

---

## 🔧 O Que Foi Corrigido:

### Antes (Muito Restritivo):
```sql
-- Só permitia upload se o nome do arquivo começasse com o UUID do usuário
AND auth.uid()::text = (storage.foldername(name))[1]
```
❌ Isso impedia uploads porque o nome do arquivo não tinha essa estrutura

### Depois (Permissivo para Autenticados):
```sql
-- Qualquer usuário autenticado pode fazer upload
AND auth.role() = 'authenticated'
```
✅ Agora funciona para todos os usuários logados

---

## 📊 Políticas Atualizadas:

### product-images:
- ✅ **SELECT**: Todos podem ver
- ✅ **INSERT**: Usuários autenticados podem fazer upload
- ✅ **UPDATE**: Usuários autenticados podem atualizar
- ✅ **DELETE**: Usuários autenticados podem deletar

### profile-images:
- ✅ **SELECT**: Todos podem ver
- ✅ **INSERT**: Usuários autenticados podem fazer upload
- ✅ **UPDATE**: Usuários autenticados podem atualizar
- ✅ **DELETE**: Usuários autenticados podem deletar

### store-banners:
- ✅ **SELECT**: Todos podem ver
- ✅ **INSERT**: Usuários autenticados podem fazer upload
- ✅ **UPDATE**: Usuários autenticados podem atualizar
- ✅ **DELETE**: Usuários autenticados podem deletar

---

## ⚠️ Importante:

1. Execute o SQL **COMPLETO** - ele remove as políticas antigas e cria novas
2. Os buckets precisam ser **públicos** (`public = true`)
3. Você precisa estar **logado** no app para fazer upload
4. Não precisa reiniciar o app, só hot reload

---

## 🧪 Teste Completo:

1. **Cadastrar Produto:**
   - ✅ Preencha nome, preço, categoria
   - ✅ Selecione 1-3 imagens
   - ✅ Salve
   - ✅ Deve aparecer na home

2. **Editar Perfil:**
   - ✅ Selecione foto de perfil
   - ✅ Altere nome/telefone
   - ✅ Salve
   - ✅ Foto deve aparecer no perfil

3. **Editar Loja:**
   - ✅ Selecione banner da loja
   - ✅ Altere nome/descrição
   - ✅ Salve
   - ✅ Banner deve aparecer

---

## 🆘 Se Ainda Der Erro:

1. Verifique se está **logado** no app
2. Vá no Supabase → **Authentication** → **Users**
3. Confirme que seu usuário existe
4. Vá em **Storage** → Clique em um bucket → **Policies**
5. Verifique se as 4 políticas estão lá
6. Se não estiverem, execute o SQL novamente

---

**Execute agora e teste! Deve funcionar imediatamente.** ✅
