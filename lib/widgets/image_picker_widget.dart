import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';

class ImagePickerWidget extends StatelessWidget {
  final List<String> selectedImages;
  final int maxImages;
  final Function(List<String>) onImagesChanged;
  final bool isCircular;
  final double size;

  const ImagePickerWidget({
    super.key,
    required this.selectedImages,
    this.maxImages = 5,
    required this.onImagesChanged,
    this.isCircular = false,
    this.size = 100,
  });

  // Imagens mockadas para fallback (quando não houver seleção real)
  static final List<String> _mockImages = [
    'assets/images/mock1.jpg',
    'assets/images/mock2.jpg',
    'assets/images/mock3.jpg',
    'assets/images/mock4.jpg',
    'assets/images/mock5.jpg',
    'assets/images/mock6.jpg',
    'assets/images/mock7.jpg',
    'assets/images/mock8.jpg',
    'assets/images/mock9.jpg',
    'assets/images/mock10.jpg',
  ];

  Future<void> _pickImage(BuildContext context) async {
    if (selectedImages.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo de $maxImages imagens atingido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Mostra opções: Câmera ou Galeria
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                  title: const Text('Galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.deepPurple),
                  title: const Text('Câmera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        // Adiciona o caminho local da imagem
        final updatedImages = List<String>.from(selectedImages)..add(image.path);
        onImagesChanged(updatedImages);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagem adicionada - pronta para upload'),
              duration: Duration(milliseconds: 800),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Se houver erro (ex: permissão negada), usa imagem mockada como fallback
      if (context.mounted) {
        final random = Random();
        final mockImage = _mockImages[random.nextInt(_mockImages.length)];
        
        final updatedImages = List<String>.from(selectedImages)..add(mockImage);
        onImagesChanged(updatedImages);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem mockada adicionada (para desenvolvimento)'),
            duration: Duration(milliseconds: 800),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    final updatedImages = List<String>.from(selectedImages)..removeAt(index);
    onImagesChanged(updatedImages);
  }

  @override
  Widget build(BuildContext context) {
    if (isCircular) {
      // Modo circular para avatar
      return _buildCircularPicker(context);
    } else {
      // Modo grid para múltiplas imagens
      return _buildGridPicker(context);
    }
  }

  Widget _buildCircularPicker(BuildContext context) {
    final hasImage = selectedImages.isNotEmpty;
    final imagePath = hasImage ? selectedImages.first : null;
    final isAssetImage = imagePath?.startsWith('assets/') ?? false;
    final isNetworkImage = imagePath?.startsWith('http') ?? false;
    
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _pickImage(context),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                border: Border.all(
                  color: Colors.deepPurple.shade100,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: hasImage
                    ? (isNetworkImage
                        ? Image.network(
                            imagePath!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Erro ao carregar foto de perfil: $error');
                              return Icon(
                                Icons.person,
                                size: size * 0.5,
                                color: Colors.grey[400],
                              );
                            },
                          )
                        : isAssetImage
                        ? Image.asset(
                            imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: size * 0.5,
                                color: Colors.grey[400],
                              );
                            },
                          )
                        : Image.file(
                            File(imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: size * 0.5,
                                color: Colors.grey[400],
                              );
                            },
                          ))
                    : Icon(
                        Icons.person,
                        size: size * 0.5,
                        color: Colors.grey[400],
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _pickImage(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridPicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagens do Produto (${selectedImages.length}/$maxImages)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Imagens selecionadas
            ...selectedImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return _buildImageCard(image, index, context);
            }).toList(),
            
            // Botão adicionar
            if (selectedImages.length < maxImages)
              _buildAddButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCard(String image, int index, BuildContext context) {
    final isAssetImage = image.startsWith('assets/');
    final isNetworkImage = image.startsWith('http');
    
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
            border: Border.all(
              color: Colors.deepPurple.shade100,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isNetworkImage
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Erro ao carregar imagem do produto: $error');
                      return Icon(Icons.image_not_supported, color: Colors.grey[400]);
                    },
                  )
                : isAssetImage
                ? Image.asset(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image_not_supported, color: Colors.grey[400]);
                    },
                  )
                : Image.file(
                    File(image),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image_not_supported, color: Colors.grey[400]);
                    },
                  ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Principal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImage(context),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 32,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              'Adicionar',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
