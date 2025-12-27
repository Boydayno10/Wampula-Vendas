import '../models/product_model.dart';
import '../services/seller_product_service.dart';

// Função async que retorna apenas produtos dos vendedores
Future<List<ProductModel>> getMockProducts() async {
  return await SellerProductService.getProductModels();
}

// Lista vazia para compatibilidade (use getMockProducts() para dados reais)
final List<ProductModel> mockProducts = [];
