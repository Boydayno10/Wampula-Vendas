# 🎨 Ideias de Categorias para Sua Loja

## 📋 Categorias Básicas (Já Incluídas)

- 🏠 Início
- 📱 Eletrónicos
- 👨‍👩‍👧‍👦 Família
- 🍎 Alimentos
- 💄 Beleza
- 👕 Vestuário
- 🏡 Casa e Jardim
- ⚽ Desporto
- 📦 Outros

---

## 💡 Categorias Sugeridas para Adicionar

### Tecnologia & Entretenimento
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Games', '🎮', 'Jogos, consolas e acessórios gaming', 10, true),
  ('Informática', '💻', 'Computadores, laptops e periféricos', 11, true),
  ('Fotografia', '📷', 'Câmeras, lentes e equipamentos fotográficos', 12, true),
  ('Música', '🎵', 'Instrumentos musicais e equipamentos de áudio', 13, true);
```

### Veículos & Transporte
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Automóveis', '🚗', 'Carros, motas e acessórios automotivos', 14, true),
  ('Bicicletas', '🚲', 'Bicicletas e acessórios para ciclismo', 15, true);
```

### Casa & Decoração
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Móveis', '🪑', 'Móveis para casa e escritório', 16, true),
  ('Decoração', '🖼️', 'Artigos decorativos e enfeites', 17, true),
  ('Electrodomésticos', '🔌', 'Electrodomésticos para casa', 18, true),
  ('Iluminação', '💡', 'Lâmpadas, lustres e iluminação', 19, true);
```

### Moda & Acessórios
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Calçados', '👟', 'Sapatos, tênis e sandálias', 20, true),
  ('Bolsas e Malas', '👜', 'Bolsas, mochilas e malas de viagem', 21, true),
  ('Jóias', '💎', 'Jóias, relógios e bijuterias', 22, true),
  ('Óculos', '🕶️', 'Óculos de sol e armações', 23, true);
```

### Bebés & Crianças
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Bebés', '👶', 'Produtos para bebés e recém-nascidos', 24, true),
  ('Brinquedos', '🧸', 'Brinquedos e jogos infantis', 25, true),
  ('Educação', '📚', 'Livros, material escolar e educativo', 26, true);
```

### Saúde & Bem-estar
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Saúde', '🏥', 'Produtos de saúde e bem-estar', 27, true),
  ('Fitness', '🏋️', 'Equipamentos de ginástica e fitness', 28, true),
  ('Suplementos', '💊', 'Vitaminas e suplementos alimentares', 29, true);
```

### Animais
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Pets', '🐾', 'Produtos para animais de estimação', 30, true);
```

### Livros & Media
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Livros', '📖', 'Livros, revistas e publicações', 31, true),
  ('Filmes e Séries', '🎬', 'DVDs, Blu-rays e streaming', 32, true);
```

### Serviços
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Serviços', '🛠️', 'Serviços diversos', 33, true);
```

### Artesanato & Hobbies
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Artesanato', '🎨', 'Materiais para artesanato e arte', 34, true),
  ('Jardinagem', '🌱', 'Plantas, sementes e ferramentas de jardinagem', 35, true);
```

### Festas & Eventos
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Festas', '🎉', 'Artigos para festas e eventos', 36, true);
```

---

## 🌍 Categorias Específicas para Moçambique

```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Capulanas', '👗', 'Capulanas tradicionais e tecidos africanos', 37, true),
  ('Artesanato Local', '🏺', 'Artesanato moçambicano', 38, true),
  ('Produtos Locais', '🇲🇿', 'Produtos típicos de Moçambique', 39, true);
```

---

## 🎯 Categorias Sazonais (Ativar/Desativar conforme época)

### Natal
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Natal', '🎄', 'Produtos e decorações de Natal', 100, false);

-- Ativar em Dezembro:
UPDATE public.categories SET active = true WHERE name = 'Natal';

-- Desativar em Janeiro:
UPDATE public.categories SET active = false WHERE name = 'Natal';
```

### Volta às Aulas
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Volta às Aulas', '🎒', 'Material escolar e uniformes', 101, false);

-- Ativar em Janeiro/Fevereiro:
UPDATE public.categories SET active = true WHERE name = 'Volta às Aulas';
```

### Promoções
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Black Friday', '🏷️', 'Promoções especiais Black Friday', 102, false),
  ('Liquidação', '💰', 'Produtos em liquidação', 103, false);
```

---

## 🚀 Como Usar Essas Ideias

### 1. Escolher Categorias Relevantes
Não adicione todas de uma vez! Escolha as que fazem sentido para seu negócio.

### 2. Começar com o Básico
Mantenha as 9 categorias padrão e adicione 3-5 categorias mais importantes para você.

### 3. Adicionar Gradualmente
À medida que seu catálogo cresce, adicione mais categorias conforme necessário.

### 4. Organizar por Prioridade
Use `display_order` para colocar categorias mais importantes primeiro.

```sql
-- Exemplo: Colocar "Games" logo após "Eletrónicos"
UPDATE public.categories SET display_order = 2 WHERE name = 'Games';
UPDATE public.categories SET display_order = 3 WHERE name = 'Eletrónicos';
```

---

## 📊 Exemplo de Estrutura Recomendada

Para um **Marketplace Geral**:
1. Início 🏠
2. Eletrónicos 📱
3. Moda e Vestuário 👕
4. Casa e Jardim 🏡
5. Saúde e Beleza 💄
6. Desporto e Fitness ⚽
7. Bebés e Crianças 👶
8. Automóveis 🚗
9. Outros 📦

Para uma **Loja de Tecnologia**:
1. Início 🏠
2. Telemóveis 📱
3. Computadores 💻
4. Tablets e E-readers 📖
5. Games 🎮
6. Fotografia 📷
7. Áudio e Som 🎵
8. Acessórios 🔌
9. Outros 📦

Para uma **Loja de Moda**:
1. Início 🏠
2. Feminino 👗
3. Masculino 👔
4. Infantil 👶
5. Calçados 👟
6. Bolsas 👜
7. Acessórios ⌚
8. Jóias 💎
9. Outros 📦

---

## 💡 Dicas Profissionais

### 1. Nomes Claros
Use nomes simples e diretos que o cliente entenda imediatamente.

### 2. Ícones Apropriados
Escolha emojis que representem bem a categoria.

### 3. Descrições Úteis
Ajudam no futuro quando tiver muitas categorias.

### 4. Não Exagere
10-15 categorias principais são suficientes. Use subcategorias depois.

### 5. Monitorar Uso
```sql
-- Ver categorias com mais produtos:
SELECT 
  c.name,
  COUNT(p.id) as total_produtos
FROM public.categories c
LEFT JOIN public.products p ON p.category = c.name AND p.active = true
WHERE c.active = true
GROUP BY c.name
ORDER BY total_produtos DESC;
```

---

## 🔄 Manutenção Regular

### Mensal
- Verificar categorias sem produtos
- Ajustar ordem de exibição
- Desativar categorias vazias

### Sazonal
- Ativar categorias de época
- Criar promoções especiais
- Destacar categorias populares

---

## 🎯 Conclusão

**Comece simples, cresça com demanda!**

Não precisa adicionar todas essas categorias agora. Comece com as básicas e adicione novas conforme seu negócio cresce.

**A beleza do sistema dinâmico é que você pode fazer isso A QUALQUER MOMENTO em poucos segundos! 🚀**
