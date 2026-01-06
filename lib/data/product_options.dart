/// Opções padrão para produtos

class ProductOptions {
  // Tamanhos de roupas (S, M, L, XL, etc.)
  static const List<String> clothingSizes = [
    'PP',
    'P',
    'M',
    'G',
    'GG',
    'XG',
    'XXG',
  ];

  // Tamanhos de calças (numeração)
  static const List<String> pantSizes = [
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    '42',
    '44',
    '46',
    '48',
  ];

  // Tamanhos de calçados (numeração brasileira)
  static const List<String> shoeSizes = [
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
    '39',
    '40',
    '41',
    '42',
    '43',
    '44',
    '45',
    '46',
  ];

  // Faixa etária para roupas infantis
  static const List<String> ageGroups = [
    'RN (Recém-nascido)',
    '0-3M',
    '3-6M',
    '6-9M',
    '9-12M',
    '12-18M',
    '18-24M',
    '2-3A',
    '3-4A',
    '4-5A',
    '5-6A',
    '6-7A',
    '7-8A',
    '8-9A',
    '9-10A',
    '10-12A',
    '12-14A',
    '14-16A',
  ];

  // Armazenamento para eletrônicos (celulares, tablets, etc.)
  static const List<String> storageOptions = [
    '16GB',
    '32GB',
    '64GB',
    '128GB',
    '256GB',
    '512GB',
    '1TB',
  ];

  // Cores disponíveis
  static const List<String> colors = [
    'Preto',
    'Branco',
    'Cinza',
    'Azul',
    'Azul Marinho',
    'Vermelho',
    'Verde',
    'Amarelo',
    'Laranja',
    'Rosa',
    'Roxo',
    'Marrom',
    'Bege',
    'Dourado',
    'Prateado',
    'Multicolor',
  ];

  // Categorias de produtos
  static const Map<String, List<String>> categoryOptions = {
    'Eletrônicos': ['Armazenamento', 'Cor'],
    'Roupas': ['Tamanho', 'Cor'],
    'Calçados': ['Tamanho de Calçado', 'Cor'],
    'Calças': ['Tamanho de Calça', 'Cor'],
    'Infantil': ['Faixa Etária', 'Cor'],
    'Beleza': ['Cor'],
    'Casa': ['Cor'],
  };

  // Verificar quais opções devem estar habilitadas por categoria
  static Map<String, bool> getDefaultOptionsForCategory(String category) {
    final options = {
      'hasSizeOption': false,
      'hasColorOption': true, // Cor disponível para quase tudo
      'hasAgeOption': false,
      'hasStorageOption': false,
      'hasPantSizeOption': false,
      'hasShoeSizeOption': false,
    };

    switch (category) {
      case 'Eletrônicos':
        options['hasStorageOption'] = true;
        break;
      case 'Roupas':
        options['hasSizeOption'] = true;
        break;
      case 'Calçados':
        options['hasShoeSizeOption'] = true;
        break;
      case 'Calças':
        options['hasPantSizeOption'] = true;
        break;
      case 'Infantil':
        options['hasAgeOption'] = true;
        break;
    }

    return options;
  }
}
