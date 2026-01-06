# 📸 Guia de Teste - Upload de Imagens

## ✅ O que foi implementado

Agora o app está **totalmente integrado com Supabase Storage** para upload de imagens:

### 1. **Imagens de Produtos** 🛍️
- Upload automático ao criar/editar produto
- Bucket: `product-images`
- Formato: `{userId}/{timestamp}.jpg`

### 2. **Fotos de Perfil** 👤
- Upload ao criar conta ou editar perfil
- Bucket: `profile-images`
- Formato: `{userId}/{timestamp}.jpg`

### 3. **Banners de Loja** 🏪
- Upload ao editar informações da loja
- Bucket: `store-banners`
- Formato: `{userId}/{timestamp}.jpg`

---

## 🔧 Arquivos Modificados

### ✅ `lib/services/image_upload_service.dart`
**Antes**: Apenas retornava caminhos locais
**Agora**: Faz upload real para Supabase Storage

**Novos métodos**:
```dart
- uploadImage() - Upload genérico
- uploadProductImage() - Upload de produtos
- uploadProfileImage() - Upload de perfil
- uploadStoreBanner() - Upload de banners
- deleteImage() - Deletar imagens
```

### ✅ `lib/screens/seller/seller_product_form.dart`
**Mudança**: Adicionado upload automático da imagem do produto antes de salvar

```dart
// Linha ~133 - Upload automático
String uploadedImageUrl = img;
if (img.isNotEmpty && !img.startsWith('http') && !img.startsWith('assets/')) {
  uploadedImageUrl = await ImageUploadService.uploadProductImage(img);
}
```

### ✅ `lib/screens/seller/seller_dashboard.dart`
**Mudança**: Upload do banner ao salvar informações da loja

```dart
// Upload do banner se foi alterado
if (currentBanner != null && !currentBanner!.startsWith('http')) {
  uploadedBannerUrl = await ImageUploadService.uploadStoreBanner(currentBanner!);
}
```

### ✅ `lib/screens/profile/edit_profile_screen.dart`
**Mudança**: Upload da foto de perfil ao salvar

```dart
// Upload da foto de perfil se foi selecionada
if (_profileImages.isNotEmpty) {
  uploadedProfileImageUrl = await ImageUploadService.uploadProfileImage(profileImage);
}
```

### ✅ `lib/models/user_model.dart`
**Mudança**: Adicionado campo `profileImageUrl`

```dart
String? profileImageUrl; // URL da foto de perfil
```

---

## ⚠️ IMPORTANTE: Configure o Storage ANTES de testar!

### 📋 Pré-requisitos

1. ✅ Execute o SQL no Supabase: `supabase_complete_setup.sql`
2. ✅ Configure os buckets seguindo: `SUPABASE_STORAGE_SETUP.md`
3. ✅ Crie os 3 buckets públicos:
   - `product-images`
   - `profile-images`
   - `store-banners`
4. ✅ Aplique as políticas RLS em cada bucket

---

## 🧪 Como Testar

### Teste 1: Upload de Foto de Perfil

1. **Abra o app** e faça login
2. Vá para **Perfil** → **Editar Perfil**
3. **Toque no avatar circular** (botão de câmera)
4. **Selecione uma foto** da galeria ou tire uma foto
5. **Clique em Salvar**
6. ✅ **Resultado esperado**: 
   - Foto é enviada para `profile-images/{userId}/...`
   - URL do Supabase é salva no perfil
   - Foto aparece no perfil

### Teste 2: Upload de Banner da Loja

1. **Entre como vendedor**
2. Vá para **Dashboard do Vendedor**
3. **Toque no card da loja** (card roxo no topo)
4. **Clique em "Adicionar Banner"**
5. **Selecione uma imagem**
6. **Preencha nome/descrição** e clique em **Salvar**
7. ✅ **Resultado esperado**:
   - Banner é enviado para `store-banners/{userId}/...`
   - URL do Supabase é salva
   - Banner aparece no dashboard

### Teste 3: Upload de Imagem de Produto

1. **Entre como vendedor**
2. Vá para **Meus Produtos**
3. **Clique em "+" (adicionar produto)**
4. **Toque na área de imagens** (botão com ícone de câmera)
5. **Selecione até 5 fotos**
6. **Preencha os dados do produto**
7. **Clique em Salvar**
8. ✅ **Resultado esperado**:
   - Primeira imagem é enviada para `product-images/{userId}/...`
   - URL do Supabase é salva no produto
   - Produto aparece na lista com a foto

---

## 🔍 Verificar no Supabase Dashboard

### Após cada upload, verifique:

1. **Vá para Storage** no Supabase Dashboard
2. **Clique no bucket** (product-images, profile-images ou store-banners)
3. **Veja a estrutura de pastas**: `{userId}/imagem.jpg`
4. **Clique na imagem** para visualizar
5. **Copie a URL pública** e teste no navegador

---

## 📊 Estrutura de URLs Geradas

### Exemplo de URLs:

```
# Foto de perfil
https://seu-projeto.supabase.co/storage/v1/object/public/profile-images/abc123/1735075200000.jpg

# Banner da loja
https://seu-projeto.supabase.co/storage/v1/object/public/store-banners/abc123/1735075300000.jpg

# Produto
https://seu-projeto.supabase.co/storage/v1/object/public/product-images/abc123/1735075400000.jpg
```

---

## 🐛 Troubleshooting

### Erro: "Bucket not found"
**Solução**: Crie os buckets no Supabase Storage (ver `SUPABASE_STORAGE_SETUP.md`)

### Erro: "Policy violation"
**Solução**: Aplique as políticas RLS nos buckets

### Erro: "User not authenticated"
**Solução**: Faça login antes de tentar fazer upload

### Erro: "File too large"
**Solução**: Verifique os limites:
- Produtos: 5MB
- Perfil: 2MB
- Banners: 3MB

### Imagem não aparece após upload
**Solução**: 
1. Verifique se o bucket é **público**
2. Verifique a URL no banco de dados
3. Teste a URL diretamente no navegador

---

## 🎯 Checklist Final

Antes de considerar concluído:

- [ ] Buckets criados no Supabase
- [ ] Políticas RLS aplicadas
- [ ] Foto de perfil funcionando
- [ ] Banner da loja funcionando
- [ ] Imagens de produtos funcionando
- [ ] URLs salvas corretamente no banco
- [ ] Imagens visíveis no app

---

## 📝 Observações Técnicas

### Formato de nomes de arquivo:
- **userId**: ID do usuário do Supabase Auth
- **timestamp**: Milissegundos desde epoch
- **extensão**: Preservada do arquivo original

### Cache:
- URLs são públicas e cacheadas por 1 hora (`cache-control: 3600`)

### Segurança:
- Usuários só podem fazer upload em suas próprias pastas
- Todos podem **visualizar** imagens (buckets públicos)
- Apenas donos podem **modificar/deletar** suas imagens

---

## 🚀 Próximos Passos

Após confirmar que o upload funciona:

1. ✅ Testar edição de produtos (atualização de imagens)
2. ✅ Testar deleção de produtos (remover imagens antigas)
3. ✅ Implementar compressão de imagens (otimizar tamanho)
4. ✅ Implementar múltiplas imagens por produto (galeria)
