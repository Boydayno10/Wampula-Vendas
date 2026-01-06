# Configuração do Supabase Storage

## Por que preciso do Storage?

O app Wampula Vendas usa imagens para:
- **Produtos**: Fotos dos produtos vendidos
- **Perfis**: Fotos de perfil dos usuários
- **Lojas**: Banners das lojas dos vendedores

Essas imagens precisam ser armazenadas no **Supabase Storage** (buckets).

---

## 📁 Passo 1: Criar os Buckets

### No Supabase Dashboard:

1. Vá para **Storage** no menu lateral
2. Clique em **"New bucket"**
3. Crie os seguintes buckets:

#### Bucket 1: `product-images`
- **Name**: `product-images`
- **Public bucket**: ✅ **SIM** (marque esta opção)
- **File size limit**: 5MB
- **Allowed MIME types**: `image/jpeg`, `image/jpg`, `image/png`, `image/webp`

#### Bucket 2: `profile-images`
- **Name**: `profile-images`
- **Public bucket**: ✅ **SIM** (marque esta opção)
- **File size limit**: 2MB
- **Allowed MIME types**: `image/jpeg`, `image/jpg`, `image/png`, `image/webp`

#### Bucket 3: `store-banners`
- **Name**: `store-banners`
- **Public bucket**: ✅ **SIM** (marque esta opção)
- **File size limit**: 3MB
- **Allowed MIME types**: `image/jpeg`, `image/jpg`, `image/png`, `image/webp`

---

## 🔒 Passo 2: Configurar Políticas de Segurança (RLS)

### Para cada bucket, configure as políticas:

### Bucket: `product-images`

```sql
-- 1️⃣ Todos podem VER imagens de produtos
CREATE POLICY "Todos podem ver imagens de produtos"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

-- 2️⃣ Usuários autenticados podem FAZER UPLOAD
CREATE POLICY "Usuários podem fazer upload de imagens de produtos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'product-images' 
  AND auth.role() = 'authenticated'
);

-- 3️⃣ Vendedores podem ATUALIZAR suas próprias imagens
CREATE POLICY "Vendedores podem atualizar suas imagens de produtos"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'product-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 4️⃣ Vendedores podem DELETAR suas próprias imagens
CREATE POLICY "Vendedores podem deletar suas imagens de produtos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'product-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

### Bucket: `profile-images`

```sql
-- 1️⃣ Todos podem VER fotos de perfil
CREATE POLICY "Todos podem ver fotos de perfil"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-images');

-- 2️⃣ Usuários podem fazer UPLOAD da própria foto
CREATE POLICY "Usuários podem fazer upload de foto de perfil"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'profile-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 3️⃣ Usuários podem ATUALIZAR a própria foto
CREATE POLICY "Usuários podem atualizar sua foto de perfil"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'profile-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 4️⃣ Usuários podem DELETAR a própria foto
CREATE POLICY "Usuários podem deletar sua foto de perfil"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'profile-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

### Bucket: `store-banners`

```sql
-- 1️⃣ Todos podem VER banners de lojas
CREATE POLICY "Todos podem ver banners de lojas"
ON storage.objects FOR SELECT
USING (bucket_id = 'store-banners');

-- 2️⃣ Vendedores podem fazer UPLOAD de banner
CREATE POLICY "Vendedores podem fazer upload de banner"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'store-banners'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 3️⃣ Vendedores podem ATUALIZAR seu banner
CREATE POLICY "Vendedores podem atualizar seu banner"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'store-banners'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 4️⃣ Vendedores podem DELETAR seu banner
CREATE POLICY "Vendedores podem deletar seu banner"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'store-banners'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

---

## 📋 Como aplicar as políticas:

1. Vá para **Storage** no Supabase Dashboard
2. Clique no bucket (ex: `product-images`)
3. Clique na aba **"Policies"**
4. Clique em **"New Policy"**
5. Cole o código SQL de cada política
6. Clique em **"Review"** e depois **"Save Policy"**

---

## 🔗 Passo 3: Obter URLs das Imagens

### No código Flutter, use:

```dart
// Upload de imagem
final file = File(imagePath);
final fileName = '${userId}/produto_${DateTime.now().millisecondsSinceEpoch}.jpg';

await Supabase.instance.client.storage
    .from('product-images')
    .upload(fileName, file);

// Obter URL pública
final imageUrl = Supabase.instance.client.storage
    .from('product-images')
    .getPublicUrl(fileName);

// Salvar imageUrl no banco de dados
```

---

## ✅ Verificação

Depois de configurar, teste:

1. **Upload**: Tente fazer upload de uma imagem de produto no app
2. **Visualização**: Verifique se a imagem aparece corretamente
3. **Segurança**: Tente acessar/deletar imagens de outro usuário (deve falhar)

---

## 📝 Estrutura de Pastas

As imagens serão organizadas assim:

```
product-images/
├── {user_id_1}/
│   ├── produto_123456.jpg
│   └── produto_789012.jpg
└── {user_id_2}/
    └── produto_345678.jpg

profile-images/
├── {user_id_1}/
│   └── avatar.jpg
└── {user_id_2}/
    └── avatar.jpg

store-banners/
├── {user_id_1}/
│   └── banner.jpg
└── {user_id_2}/
    └── banner.jpg
```

---

## ⚠️ Importante

- **Buckets públicos**: As imagens são acessíveis por URL, mas só o dono pode modificar/deletar
- **Tamanho máximo**: Configure limites adequados (5MB para produtos, 2MB para perfis)
- **Formatos**: Apenas JPEG, JPG, PNG e WebP são permitidos
- **Organização**: Cada usuário tem sua pasta (usando UUID do auth)

---

## 🔧 Próximas Etapas

Depois de configurar o Storage, você precisa:

1. ✅ Executar `supabase_complete_setup.sql` (tabelas e triggers)
2. ✅ Criar os 3 buckets acima (Storage)
3. ✅ Aplicar as políticas de segurança
4. 🧪 Testar upload de imagens no app
