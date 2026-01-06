import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Processa uma imagem para o formato quadrado 1:1 antes do upload.
///
/// - Recorta centralmente para um quadrado.
/// - Garante resolução mínima de 1024x1024 (faz upscale apenas se necessário).
/// - Faz uma leve compressão para reduzir o tamanho do arquivo.
///
/// Em caso de erro, retorna o próprio arquivo original para não quebrar o fluxo.
Future<File> processImageToSquare(File image) async {
  try {
    if (!await image.exists()) {
      throw Exception('Arquivo de imagem não encontrado: ${image.path}');
    }

    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Não foi possível decodificar a imagem.');
    }

    // 1) Recorte central para quadrado
    final int srcWidth = decoded.width;
    final int srcHeight = decoded.height;
    final int squareSize = srcWidth < srcHeight ? srcWidth : srcHeight;

    final int offsetX = (srcWidth - squareSize) ~/ 2;
    final int offsetY = (srcHeight - squareSize) ~/ 2;

    img.Image square = img.copyCrop(
      decoded,
      x: offsetX,
      y: offsetY,
      width: squareSize,
      height: squareSize,
    );

    // 2) Garantir tamanho mínimo de 1024x1024
    const int targetSize = 1024;
    if (square.width != targetSize || square.height != targetSize) {
      // Se a imagem for menor que 1024, faz upscale suave até 1024.
      // Se for maior, faz downscale para 1024 para equilibrar qualidade x peso.
      square = img.copyResize(
        square,
        width: targetSize,
        height: targetSize,
        interpolation: img.Interpolation.cubic,
      );
    }

    // 3) Codificar em JPEG de boa qualidade
    final Uint8List encodedJpg = Uint8List.fromList(
      img.encodeJpg(square, quality: 92),
    );

    // 4) Compressão leve extra
    final List<int> compressedBytes =
        await FlutterImageCompress.compressWithList(
          encodedJpg,
          quality: 88,
          format: CompressFormat.jpeg,
          minWidth: targetSize,
          minHeight: targetSize,
        );

    final String tempPath =
        '${Directory.systemTemp.path}/wampula_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File processed = File(tempPath);
    await processed.writeAsBytes(compressedBytes, flush: true);

    return processed;
  } catch (e) {
    // Em caso de falha, registra no log e continua com a imagem original
    // para não interromper o fluxo de upload.
    // ignore: avoid_print
    print('Erro ao processar imagem para quadrado: $e');
    return image;
  }
}

/// Processa uma imagem para uso em banner horizontal.
///
/// - Recorta centralmente para proporção 16:9.
/// - Garante resolução aproximada de 1280x720.
/// - Faz compressão leve para reduzir o tamanho.
///
/// Em caso de erro, retorna o arquivo original.
Future<File> processImageToBanner(File image) async {
  try {
    if (!await image.exists()) {
      throw Exception('Arquivo de imagem não encontrado: ${image.path}');
    }

    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Não foi possível decodificar a imagem.');
    }

    const double targetAspect = 16 / 9;
    int srcWidth = decoded.width;
    int srcHeight = decoded.height;
    double currentAspect = srcWidth / srcHeight;

    // Recorte central para 16:9 mantendo o máximo de área possível.
    int cropWidth = srcWidth;
    int cropHeight = srcHeight;

    if (currentAspect > targetAspect) {
      // Muito largo, reduzir largura
      cropWidth = (srcHeight * targetAspect).round();
    } else if (currentAspect < targetAspect) {
      // Muito alto, reduzir altura
      cropHeight = (srcWidth / targetAspect).round();
    }

    final offsetX = (srcWidth - cropWidth) ~/ 2;
    final offsetY = (srcHeight - cropHeight) ~/ 2;

    img.Image banner = img.copyCrop(
      decoded,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );

    // Redimensionar para 1280x720 para equilíbrio qualidade/peso
    const int targetWidth = 1280;
    const int targetHeight = 720;

    banner = img.copyResize(
      banner,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );

    final Uint8List encodedJpg = Uint8List.fromList(
      img.encodeJpg(banner, quality: 90),
    );

    final List<int> compressedBytes =
        await FlutterImageCompress.compressWithList(
          encodedJpg,
          quality: 86,
          format: CompressFormat.jpeg,
          minWidth: targetWidth,
          minHeight: targetHeight,
        );

    final String tempPath =
        '${Directory.systemTemp.path}/wampula_banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File processed = File(tempPath);
    await processed.writeAsBytes(compressedBytes, flush: true);

    return processed;
  } catch (e) {
    // ignore: avoid_print
    print('Erro ao processar imagem para banner: $e');
    return image;
  }
}
