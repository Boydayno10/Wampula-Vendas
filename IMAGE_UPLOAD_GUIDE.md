# Sistema de Upload de Imagens

## Status Atual
O sistema de seleção de imagens está **totalmente funcional** e pronto para uso. Os usuários podem:
- Selecionar imagens da galeria
- Tirar fotos com a câmera
- Ver preview das imagens selecionadas
- Remover imagens

Por enquanto, as imagens ficam armazenadas localmente no dispositivo. Quando integrar com Firebase, basta seguir os passos abaixo.

## Onde funciona
✅ **Avatar do perfil** - Criar conta e editar perfil  
✅ **Banner da loja** - Dashboard do vendedor  
✅ **Imagens de produtos** - Cadastro de produtos (até 5 imagens)  

## Como funciona agora
1. Usuário clica para adicionar imagem
2. Escolhe entre Galeria ou Câmera
3. Seleciona/tira a foto
4. Imagem fica salva localmente (path do arquivo)
5. Preview funciona perfeitamente

## Integração com Firebase Storage (Futuro)

### Passo 1: Configurar Firebase Storage
```dart
// Já está no pubspec.yaml:
// firebase_storage: ^11.6.0
```

### Passo 2: Regras de Segurança
No Firebase Console > Storage > Rules:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/avatar/{fileName} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /stores/{storeId}/banner/{fileName} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    match /products/{productId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### Passo 3: Ativar Upload Real
No arquivo `lib/services/image_upload_service.dart`:

1. **Descomentar as linhas 5-6:**
```dart
import 'package:firebase_storage/firebase_storage.dart';
static final FirebaseStorage _storage = FirebaseStorage.instance;
```

2. **Substituir o método uploadImage (linhas 13-35):**
```dart
static Future<String> uploadImage(String localPath, {required String folder}) async {
  try {
    final file = File(localPath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(localPath)}';
    final ref = _storage.ref().child('$folder/$fileName');
    
    // Faz upload
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    // Obtém URL pública
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    
    // Deleta arquivo local após upload
    await file.delete();
    
    return downloadUrl;
  } catch (e) {
    throw Exception('Erro ao fazer upload da imagem: $e');
  }
}
```

3. **Ativar deleção real (linha 75):**
```dart
static Future<void> deleteImage(String imageUrl) async {
  try {
    if (imageUrl.startsWith('https://firebasestorage')) {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    }
  } catch (e) {
    print('Erro ao deletar imagem: $e');
  }
}
```

### Passo 4: Usar o serviço onde necessário

#### Ao salvar perfil (edit_profile_screen.dart):
```dart
// Antes de salvar, fazer upload se houver imagem nova
if (_profileImages.isNotEmpty && !_profileImages.first.startsWith('http')) {
  final uploadedUrl = await ImageUploadService.uploadImage(
    _profileImages.first,
    folder: 'users/${AuthService.currentUser.id}/avatar',
  );
  AuthService.currentUser.profileImage = uploadedUrl;
}
```

#### Ao salvar banner da loja (seller_dashboard.dart):
```dart
// Antes de salvar, fazer upload se necessário
if (currentBanner != null && !currentBanner.startsWith('http')) {
  currentBanner = await ImageUploadService.uploadImage(
    currentBanner,
    folder: 'stores/${AuthService.currentUser.id}/banner',
  );
}
AuthService.currentUser.storeBanner = currentBanner;
```

#### Ao cadastrar produto (seller_product_form.dart):
```dart
// Fazer upload de todas as imagens antes de salvar
final uploadedImages = await ImageUploadService.uploadMultipleImages(
  _productImages.where((img) => !img.startsWith('http')).toList(),
  folder: 'products/${productId}',
);
```

## Estrutura de pastas no Firebase Storage
```
storage/
  ├── users/
  │   └── {userId}/
  │       └── avatar/
  │           └── {timestamp}_image.jpg
  ├── stores/
  │   └── {storeId}/
  │       └── banner/
  │           └── {timestamp}_banner.jpg
  └── products/
      └── {productId}/
          ├── {timestamp}_image1.jpg
          ├── {timestamp}_image2.jpg
          └── ...
```

## Testando antes do Firebase
Por enquanto, você pode testar:
- ✅ Seleção de imagens funciona
- ✅ Preview funciona
- ✅ Edição/remoção funciona
- ⚠️ Imagens ficam apenas no dispositivo

## Fallback
Se houver erro ao selecionar da galeria (ex: permissões), o app usa imagens mockadas automaticamente para não quebrar a experiência de desenvolvimento.

## Permissões necessárias

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>Precisamos acessar sua câmera para tirar fotos de produtos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Precisamos acessar sua galeria para selecionar imagens</string>
```

## Próximos passos
1. ✅ Sistema de seleção implementado
2. ⏳ Integrar Firebase Storage (seguir passos acima)
3. ⏳ Adicionar progress indicator durante upload
4. ⏳ Implementar compressão de imagens
5. ⏳ Cache de imagens local
