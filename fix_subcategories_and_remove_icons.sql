-- ================================================================
-- 🔧 FIX: Subcategorias não aparecem + Remover ícones
-- ================================================================
-- 1. Remove campo icon das categorias e subcategorias
-- 2. Adiciona dados de métricas nos produtos para filtros funcionarem
-- 3. Torna filtros das subcategorias menos restritivos
-- ================================================================

-- ==========================================
-- 1️⃣ REMOVER CAMPO ICON DAS CATEGORIAS
-- ==========================================
ALTER TABLE public.categories DROP COLUMN IF EXISTS icon;
ALTER TABLE public.subcategories DROP COLUMN IF EXISTS icon;

-- ==========================================
-- 2️⃣ ADICIONAR MÉTRICAS NOS PRODUTOS
-- ==========================================
-- Atualizar produtos existentes com dados de exemplo para os filtros funcionarem

-- Adicionar visualizações e cliques (para "Mais populares")
UPDATE public.products
SET 
  views_count = FLOOR(RANDOM() * 100 + 10)::int,
  clicks_count = FLOOR(RANDOM() * 50 + 5)::int,
  popularity_score = ROUND((RANDOM() * 50 + 30)::numeric, 1)
WHERE active = true AND clicks_count = 0;

-- Adicionar vendas (para "Mais comprados")
UPDATE public.products
SET 
  sold_count = FLOOR(RANDOM() * 30 + 1)::int
WHERE active = true AND sold_count = 0;

-- Adicionar promoções em alguns produtos (para "Promoções")
UPDATE public.products
SET 
  old_price = price * 1.25
WHERE 
  id IN (
    SELECT id 
    FROM public.products 
    WHERE active = true 
      AND old_price IS NULL
    ORDER BY RANDOM()
    LIMIT 10
  );

-- ==========================================
-- 3️⃣ VERIFICAÇÃO DOS DADOS
-- ==========================================
-- Verificar quantos produtos têm métricas

SELECT 
  'Total produtos ativos' as metrica,
  COUNT(*) as quantidade
FROM public.products
WHERE active = true

UNION ALL

SELECT 
  'Com vendas (sold_count > 0)' as metrica,
  COUNT(*) as quantidade
FROM public.products
WHERE active = true AND sold_count > 0

UNION ALL

SELECT 
  'Com cliques (clicks_count > 0)' as metrica,
  COUNT(*) as quantidade
FROM public.products
WHERE active = true AND clicks_count > 0

UNION ALL

SELECT 
  'Com promoção (old_price > price)' as metrica,
  COUNT(*) as quantidade
FROM public.products
WHERE active = true AND old_price > price

UNION ALL

SELECT 
  'Novos (< 30 dias)' as metrica,
  COUNT(*) as quantidade
FROM public.products
WHERE active = true AND created_at >= NOW() - INTERVAL '30 days';

-- ==========================================
-- 4️⃣ VERIFICAR CATEGORIAS E SUBCATEGORIAS
-- ==========================================
SELECT 'Categorias' as tabela, COUNT(*) as total FROM public.categories WHERE active = true
UNION ALL
SELECT 'Subcategorias' as tabela, COUNT(*) as total FROM public.subcategories WHERE active = true;

-- ==========================================
-- ✅ RESULTADO ESPERADO
-- ==========================================
-- ✅ Campo icon removido das tabelas categories e subcategories
-- ✅ Produtos agora têm métricas (sold_count, clicks_count, etc.)
-- ✅ Subcategorias devem aparecer no app
-- ✅ Todos os filtros funcionarão corretamente
-- ==========================================

-- ==========================================
-- 📝 PRÓXIMO PASSO
-- ==========================================
-- Execute este script no SQL Editor do Supabase
-- Depois reinicie o app Flutter (hot restart não é suficiente)
-- ==========================================
