-- =====================================================
-- SETUP DE CATEGORIAS DINÂMICAS
-- =====================================================
-- Este script cria e popula a tabela de categorias
-- que será gerenciada dinamicamente pelo admin

-- A tabela já existe no schema, mas vamos garantir que ela está correta
-- Se você já tem a tabela criada, pode pular a parte de CREATE TABLE

-- Verificar se a tabela existe (executar no SQL Editor)
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public'
   AND table_name = 'categories'
);

-- Se a tabela não existir, criar:
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  icon text,
  description text,
  display_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);

-- =====================================================
-- POPULAR CATEGORIAS INICIAIS
-- =====================================================

-- Limpar categorias existentes (CUIDADO: só execute se quiser resetar)
-- DELETE FROM public.categories;

-- Inserir categorias padrão
INSERT INTO public.categories (name, icon, description, display_order, active) VALUES
  ('Início', '🏠', 'Página inicial com todos os produtos', 0, true),
  ('Eletrónicos', '📱', 'Telemóveis, tablets, computadores e acessórios', 1, true),
  ('Família', '👨‍👩‍👧‍👦', 'Produtos para toda a família', 2, true),
  ('Alimentos', '🍎', 'Comida, bebidas e mantimentos', 3, true),
  ('Beleza', '💄', 'Cosméticos, perfumes e cuidados pessoais', 4, true),
  ('Vestuário', '👕', 'Roupas, calçados e acessórios de moda', 5, true),
  ('Casa e Jardim', '🏡', 'Móveis, decoração e utensílios domésticos', 6, true),
  ('Desporto', '⚽', 'Equipamentos e artigos desportivos', 7, true),
  ('Outros', '📦', 'Outros produtos e serviços', 8, true)
ON CONFLICT (name) DO UPDATE SET
  icon = EXCLUDED.icon,
  description = EXCLUDED.description,
  display_order = EXCLUDED.display_order,
  active = EXCLUDED.active;

-- =====================================================
-- POLÍTICAS RLS (Row Level Security)
-- =====================================================

-- Habilitar RLS na tabela categories
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Remover política antiga se existir e criar nova
DROP POLICY IF EXISTS "Qualquer um pode ver categorias ativas" ON public.categories;

-- Política: Todos podem VER categorias ativas
CREATE POLICY "Qualquer um pode ver categorias ativas"
  ON public.categories
  FOR SELECT
  USING (active = true);

-- Política: Apenas admins podem INSERIR categorias
-- (Por enquanto, você vai adicionar manualmente no Supabase Dashboard)
-- Futuramente, pode criar uma tabela de admins e verificar aqui

-- Política: Apenas admins podem ATUALIZAR categorias
-- (Por enquanto, você vai editar manualmente no Supabase Dashboard)

-- Política: Apenas admins podem DELETAR categorias
-- (Por enquanto, você vai deletar manualmente no Supabase Dashboard)

-- =====================================================
-- ÍNDICES PARA PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_categories_active 
  ON public.categories(active);

CREATE INDEX IF NOT EXISTS idx_categories_display_order 
  ON public.categories(display_order);

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

-- Ver todas as categorias
SELECT 
  id,
  name,
  icon,
  description,
  display_order,
  active,
  created_at
FROM public.categories
ORDER BY display_order;

-- =====================================================
-- COMO GERENCIAR CATEGORIAS
-- =====================================================

-- Para ADICIONAR uma nova categoria:
-- INSERT INTO public.categories (name, icon, description, display_order, active) 
-- VALUES ('Nome da Categoria', '🎮', 'Descrição', 10, true);

-- Para EDITAR uma categoria:
-- UPDATE public.categories 
-- SET name = 'Novo Nome', 
--     icon = '🎯',
--     description = 'Nova descrição',
--     display_order = 5
-- WHERE id = 'UUID_DA_CATEGORIA';

-- Para DESATIVAR uma categoria (em vez de deletar):
-- UPDATE public.categories 
-- SET active = false 
-- WHERE id = 'UUID_DA_CATEGORIA';

-- Para REORDENAR categorias:
-- UPDATE public.categories SET display_order = 0 WHERE name = 'Início';
-- UPDATE public.categories SET display_order = 1 WHERE name = 'Eletrónicos';
-- UPDATE public.categories SET display_order = 2 WHERE name = 'Família';
-- etc...

-- Para DELETAR uma categoria permanentemente:
-- DELETE FROM public.categories WHERE id = 'UUID_DA_CATEGORIA';

-- =====================================================
-- IMPORTANTE!
-- =====================================================
-- 1. A categoria "Início" é especial - ela mostra TODOS os produtos
-- 2. Ao desativar uma categoria, ela não aparecerá no app
-- 3. Ao deletar uma categoria, produtos com essa categoria ainda existirão
-- 4. Use display_order para controlar a ordem no app (menor = primeiro)
-- 5. O campo icon é opcional mas ajuda na visualização futura
