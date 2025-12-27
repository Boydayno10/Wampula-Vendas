# 📂 Sistema de Categorias Dinâmicas

## 🎯 Visão Geral

O sistema de categorias foi transformado de **estático** para **dinâmico**! Agora todas as categorias são gerenciadas no Supabase e aparecem automaticamente no app.

## 🚀 Como Funciona

### 1. **No Supabase (Admin)**
- Você gerencia as categorias na tabela `categories`
- Pode adicionar, editar, desativar ou deletar categorias
- As mudanças aparecem **imediatamente** no app

### 2. **No App**
- Categorias carregam automaticamente do Supabase
- Aparecem na barra de categorias da Home
- Vendedores podem vincular produtos às categorias disponíveis
- Sistema de cache para performance

---

## 📋 Setup Inicial

### Passo 1: Executar SQL no Supabase

1. Acesse seu **Supabase Dashboard**
2. Vá em **SQL Editor**
3. Execute o arquivo `supabase_categories_setup.sql`

Este script irá:
- ✅ Criar a tabela `categories` (se não existir)
- ✅ Popular com categorias padrão
- ✅ Configurar políticas RLS
- ✅ Criar índices para performance

### Passo 2: Verificar Categorias

No SQL Editor, execute:

```sql
SELECT * FROM public.categories ORDER BY display_order;
```

Você deve ver as categorias padrão:
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

## 🛠️ Gerenciamento de Categorias

### ➕ Adicionar Nova Categoria

```sql
INSERT INTO public.categories (name, icon, description, display_order, active) 
VALUES ('Automóveis', '🚗', 'Carros, motas e acessórios', 9, true);
```

**Resultado**: A categoria aparece **imediatamente** no app!

### ✏️ Editar Categoria Existente

```sql
UPDATE public.categories 
SET name = 'Electrónicos e Tecnologia', 
    description = 'Tecnologia de ponta',
    display_order = 1
WHERE name = 'Eletrónicos';
```

### 🔄 Reordenar Categorias

O campo `display_order` controla a ordem de exibição (menor = primeiro):

```sql
-- Colocar "Beleza" em primeiro lugar (depois de "Início")
UPDATE public.categories SET display_order = 1 WHERE name = 'Beleza';
UPDATE public.categories SET display_order = 2 WHERE name = 'Eletrónicos';
UPDATE public.categories SET display_order = 3 WHERE name = 'Família';
```

### 🚫 Desativar Categoria (Esconder do App)

```sql
UPDATE public.categories 
SET active = false 
WHERE name = 'Outros';
```

**Importante**: Produtos desta categoria ainda existem, mas a categoria não aparece no app.

### ♻️ Reativar Categoria

```sql
UPDATE public.categories 
SET active = true 
WHERE name = 'Outros';
```

### 🗑️ Deletar Categoria Permanentemente

```sql
DELETE FROM public.categories 
WHERE name = 'Categoria Antiga';
```

⚠️ **Cuidado**: Esta ação é irreversível!

---

## 📱 No App Flutter

### Alterações Realizadas:

1. **Modelo de Categoria** (`category_model.dart`)
   - Representa uma categoria do Supabase
   - Campos: id, name, icon, description, display_order, active

2. **Serviço de Categorias** (`category_service.dart`)
   - Carrega categorias do Supabase
   - Sistema de cache
   - Fallback para categorias padrão se houver erro

3. **Widget CategoryBar** (`category_bar.dart`)
   - Agora dinâmico
   - Mostra loading enquanto carrega
   - Atualiza automaticamente

4. **HomeScreen** (`home_screen.dart`)
   - Carrega categorias no initState
   - Filtra produtos por categoria dinamicamente

5. **Formulário de Produto** (`seller_product_form.dart`)
   - Dropdown de categorias dinâmico
   - Carrega categorias ativas do Supabase
   - Exclui "Início" (categoria especial)

---

## 🔍 Categorias Especiais

### 🏠 Categoria "Início"

- **Função**: Mostra TODOS os produtos (misturados)
- **No App**: Sempre aparece em primeiro lugar
- **No Formulário**: NÃO aparece para vendedores (categoria reservada)

### 📦 Categoria "Outros"

- **Função**: Categoria genérica para produtos diversos
- **Pode ser desativada** se preferir forçar categorias específicas

---

## 🎨 Personalização

### Adicionar Ícones

Os ícones são opcionais mas ajudam na visualização futura:

```sql
UPDATE public.categories 
SET icon = '🎮' 
WHERE name = 'Games';
```

### Adicionar Descrição

```sql
UPDATE public.categories 
SET description = 'Jogos, consolas e acessórios gaming' 
WHERE name = 'Games';
```

---

## 🔐 Segurança (RLS)

### Políticas Atuais:

- ✅ **Leitura**: Todos podem ver categorias ativas
- ❌ **Escrita**: Apenas você (admin) via Supabase Dashboard

### Futuramente (Admin Web):

Quando criar o painel de admin, adicione políticas:

```sql
-- Exemplo: Apenas usuários com is_admin = true podem modificar
CREATE POLICY "Admins podem modificar categorias"
  ON public.categories
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );
```

---

## 🧪 Testando

### 1. Adicionar Categoria no Supabase

```sql
INSERT INTO public.categories (name, icon, description, display_order, active) 
VALUES ('Teste', '🧪', 'Categoria de teste', 99, true);
```

### 2. Abrir o App

- ✅ A categoria "Teste" deve aparecer na barra de categorias
- ✅ Ao clicar, mostra produtos dessa categoria
- ✅ No formulário do vendedor, "Teste" aparece no dropdown

### 3. Desativar Categoria

```sql
UPDATE public.categories SET active = false WHERE name = 'Teste';
```

- ✅ Categoria desaparece do app **imediatamente**

### 4. Deletar Categoria

```sql
DELETE FROM public.categories WHERE name = 'Teste';
```

---

## 📊 Consultas Úteis

### Ver todas as categorias

```sql
SELECT 
  id,
  name,
  icon,
  display_order,
  active,
  created_at
FROM public.categories
ORDER BY display_order;
```

### Contar produtos por categoria

```sql
SELECT 
  c.name AS categoria,
  COUNT(p.id) AS total_produtos
FROM public.categories c
LEFT JOIN public.products p ON p.category = c.name AND p.active = true
GROUP BY c.name
ORDER BY total_produtos DESC;
```

### Categorias sem produtos

```sql
SELECT c.name
FROM public.categories c
LEFT JOIN public.products p ON p.category = c.name AND p.active = true
WHERE c.active = true AND p.id IS NULL;
```

---

## 🚀 Próximos Passos

### 1. Criar Painel de Admin Web
- Interface visual para gerenciar categorias
- Drag & drop para reordenar
- Upload de ícones personalizados

### 2. Melhorias no App
- Ícones das categorias na barra
- Animações ao trocar de categoria
- Pull-to-refresh para recarregar categorias

### 3. Analytics
- Rastrear categorias mais visualizadas
- Categorias com mais vendas
- Sugestões de novas categorias

---

## ❓ FAQ

**P: As categorias atualizam em tempo real?**
R: O app carrega as categorias ao iniciar. Para ver mudanças imediatas, feche e abra o app novamente.

**P: Posso ter quantas categorias?**
R: Sem limite! Mas recomendamos até 15 categorias para melhor UX.

**P: E se eu deletar uma categoria com produtos?**
R: Os produtos continuam existindo com o nome da categoria antiga. É melhor DESATIVAR em vez de deletar.

**P: Como ordenar as categorias?**
R: Use o campo `display_order`. Menor valor = aparece primeiro.

**P: Posso adicionar imagens às categorias?**
R: Por enquanto só ícones (emoji). Futuramente, pode adicionar campo `image_url`.

---

## 📞 Suporte

Se tiver dúvidas ou problemas:
1. Verifique os logs do console no app
2. Confirme que as políticas RLS estão ativas
3. Verifique se a tabela `categories` existe
4. Execute queries de verificação no SQL Editor

---

## ✅ Checklist de Implementação

- [x] Criar modelo CategoryModel
- [x] Criar CategoryService
- [x] Atualizar CategoryBar para dinâmico
- [x] Atualizar HomeScreen
- [x] Atualizar formulário de produto
- [x] Criar script SQL de setup
- [x] Documentação completa
- [ ] Testar no app
- [ ] Popular categorias reais
- [ ] Criar painel de admin (futuro)

---

**🎉 Parabéns! Seu app agora tem categorias totalmente dinâmicas!**
