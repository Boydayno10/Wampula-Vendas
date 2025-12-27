-- ============================================
-- 🎯 SISTEMA DE ANALYTICS DINÂMICO
-- ============================================
-- OBJETIVO: Rastrear automaticamente todas as métricas dos produtos
-- - Visualizações (views)
-- - Cliques (clicks)
-- - Pesquisas (searches)
-- - Vendas (sold_count)
-- - Popularidade calculada dinamicamente
-- ============================================

-- ============================================
-- 1️⃣ ADICIONAR COLUNAS DE ANALYTICS NA TABELA PRODUCTS
-- ============================================

-- Adicionar colunas se não existirem
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS views_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS clicks_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS search_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_viewed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS popularity_score DECIMAL(5,2) DEFAULT 0;

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_products_views ON public.products(views_count DESC);
CREATE INDEX IF NOT EXISTS idx_products_clicks ON public.products(clicks_count DESC);
CREATE INDEX IF NOT EXISTS idx_products_popularity ON public.products(popularity_score DESC);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON public.products(created_at DESC);

-- ============================================
-- 2️⃣ FUNÇÃO PARA REGISTRAR VISUALIZAÇÃO
-- ============================================

CREATE OR REPLACE FUNCTION public.track_product_view(product_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET 
    views_count = views_count + 1,
    last_viewed_at = NOW()
  WHERE id = product_id AND active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 3️⃣ FUNÇÃO PARA REGISTRAR CLIQUE
-- ============================================

CREATE OR REPLACE FUNCTION public.track_product_click(product_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET clicks_count = clicks_count + 1
  WHERE id = product_id AND active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 4️⃣ FUNÇÃO PARA REGISTRAR PESQUISA
-- ============================================

CREATE OR REPLACE FUNCTION public.track_product_search(product_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET search_count = search_count + 1
  WHERE id = product_id AND active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5️⃣ TRIGGER PARA ATUALIZAR sold_count AUTOMATICAMENTE
-- ============================================

-- Função que incrementa sold_count quando pedido é entregue
CREATE OR REPLACE FUNCTION public.increment_sold_count()
RETURNS TRIGGER AS $$
BEGIN
  -- Só incrementa se o status mudou para "entregue"
  IF NEW.status = 'entregue' AND OLD.status != 'entregue' THEN
    UPDATE public.products
    SET sold_count = sold_count + NEW.quantity
    WHERE id = NEW.product_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger na tabela seller_orders
DROP TRIGGER IF EXISTS trigger_increment_sold_count ON public.seller_orders;
CREATE TRIGGER trigger_increment_sold_count
  AFTER UPDATE ON public.seller_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_sold_count();

-- ============================================
-- 6️⃣ FUNÇÃO PARA CALCULAR POPULARIDADE DINAMICAMENTE
-- ============================================

-- Recalcula popularity_score baseado em múltiplas métricas
CREATE OR REPLACE FUNCTION public.calculate_popularity_score(product_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  score DECIMAL(5,2);
  p_views INT;
  p_clicks INT;
  p_searches INT;
  p_sold INT;
  days_since_created INT;
BEGIN
  -- Buscar métricas do produto
  SELECT 
    views_count,
    clicks_count,
    search_count,
    sold_count,
    EXTRACT(DAY FROM NOW() - created_at)::INT
  INTO p_views, p_clicks, p_searches, p_sold, days_since_created
  FROM public.products
  WHERE id = product_id;
  
  -- Fórmula de popularidade (score de 0-100):
  -- - Visualizações: 30%
  -- - Cliques: 25%
  -- - Pesquisas: 20%
  -- - Vendas: 25%
  -- Produtos mais recentes recebem boost
  
  score := (
    (p_views * 0.3) +
    (p_clicks * 0.5) +
    (p_searches * 0.8) +
    (p_sold * 2.0)
  );
  
  -- Boost para produtos recentes (primeiros 30 dias)
  IF days_since_created <= 30 THEN
    score := score * 1.2;
  END IF;
  
  -- Limitar entre 0 e 100
  IF score > 100 THEN
    score := 100;
  END IF;
  
  -- Atualizar o score no produto
  UPDATE public.products
  SET popularity_score = score
  WHERE id = product_id;
  
  RETURN score;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7️⃣ TRIGGER PARA RECALCULAR POPULARIDADE AUTOMATICAMENTE
-- ============================================

CREATE OR REPLACE FUNCTION public.auto_recalculate_popularity()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalcula quando views, clicks, searches ou sold_count mudam
  IF (NEW.views_count != OLD.views_count OR 
      NEW.clicks_count != OLD.clicks_count OR 
      NEW.search_count != OLD.search_count OR 
      NEW.sold_count != OLD.sold_count) THEN
    
    PERFORM public.calculate_popularity_score(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_recalculate_popularity ON public.products;
CREATE TRIGGER trigger_auto_recalculate_popularity
  AFTER UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_recalculate_popularity();

-- ============================================
-- 8️⃣ FUNÇÃO PARA OBTER PRODUTOS MAIS POPULARES
-- ============================================

CREATE OR REPLACE FUNCTION public.get_most_popular_products(
  p_category TEXT DEFAULT NULL,
  p_limit INT DEFAULT 10
)
RETURNS TABLE(
  id UUID,
  name TEXT,
  price DECIMAL,
  popularity_score DECIMAL,
  views_count INT,
  sold_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.name,
    p.price,
    p.popularity_score,
    p.views_count,
    p.sold_count
  FROM public.products p
  WHERE 
    p.active = true
    AND p.stock > 0
    AND (p_category IS NULL OR p.category = p_category)
  ORDER BY p.popularity_score DESC, p.views_count DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9️⃣ FUNÇÃO PARA OBTER PRODUTOS MAIS VENDIDOS
-- ============================================

CREATE OR REPLACE FUNCTION public.get_best_selling_products(
  p_category TEXT DEFAULT NULL,
  p_limit INT DEFAULT 10
)
RETURNS TABLE(
  id UUID,
  name TEXT,
  price DECIMAL,
  sold_count INT,
  popularity_score DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.name,
    p.price,
    p.sold_count,
    p.popularity_score
  FROM public.products p
  WHERE 
    p.active = true
    AND p.stock > 0
    AND p.sold_count > 0
    AND (p_category IS NULL OR p.category = p_category)
  ORDER BY p.sold_count DESC, p.popularity_score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 🔟 FUNÇÃO PARA OBTER PRODUTOS NOVOS (ÚLTIMOS 30 DIAS)
-- ============================================

CREATE OR REPLACE FUNCTION public.get_new_products(
  p_category TEXT DEFAULT NULL,
  p_days INT DEFAULT 30,
  p_limit INT DEFAULT 10
)
RETURNS TABLE(
  id UUID,
  name TEXT,
  price DECIMAL,
  created_at TIMESTAMPTZ,
  days_old INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.name,
    p.price,
    p.created_at,
    EXTRACT(DAY FROM NOW() - p.created_at)::INT as days_old
  FROM public.products p
  WHERE 
    p.active = true
    AND p.stock > 0
    AND p.created_at >= NOW() - (p_days || ' days')::INTERVAL
    AND (p_category IS NULL OR p.category = p_category)
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 1️⃣1️⃣ TABELA DE LOG DE PESQUISAS (OPCIONAL - PARA ANALYTICS)
-- ============================================

CREATE TABLE IF NOT EXISTS public.search_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  search_term TEXT NOT NULL,
  results_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para pesquisas rápidas
CREATE INDEX IF NOT EXISTS idx_search_logs_term ON public.search_logs(search_term);
CREATE INDEX IF NOT EXISTS idx_search_logs_created ON public.search_logs(created_at DESC);

-- Função para registrar pesquisa
CREATE OR REPLACE FUNCTION public.log_search(
  p_user_id UUID,
  p_search_term TEXT,
  p_results_count INT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.search_logs (user_id, search_term, results_count)
  VALUES (p_user_id, p_search_term, p_results_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 1️⃣2️⃣ RECALCULAR POPULARIDADE DE TODOS OS PRODUTOS
-- ============================================

-- Execute isto uma vez para inicializar scores
DO $$
DECLARE
  product RECORD;
BEGIN
  FOR product IN SELECT id FROM public.products WHERE active = true
  LOOP
    PERFORM public.calculate_popularity_score(product.id);
  END LOOP;
END $$;

-- ============================================
-- 1️⃣3️⃣ QUERIES DE VERIFICAÇÃO
-- ============================================

-- Ver produtos mais populares
SELECT 
  name,
  category,
  views_count,
  clicks_count,
  search_count,
  sold_count,
  popularity_score
FROM public.products
WHERE active = true
ORDER BY popularity_score DESC
LIMIT 10;

-- Ver produtos mais vendidos
SELECT 
  name,
  category,
  sold_count,
  popularity_score
FROM public.products
WHERE active = true AND sold_count > 0
ORDER BY sold_count DESC
LIMIT 10;

-- Ver produtos novos (últimos 30 dias)
SELECT 
  name,
  category,
  created_at,
  EXTRACT(DAY FROM NOW() - created_at)::INT as days_old
FROM public.products
WHERE 
  active = true 
  AND created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

-- Ver produtos mais pesquisados
SELECT 
  name,
  category,
  search_count,
  popularity_score
FROM public.products
WHERE active = true AND search_count > 0
ORDER BY search_count DESC
LIMIT 10;

-- ============================================
-- ✅ PRONTO!
-- ============================================
-- Agora o sistema rastreia automaticamente:
-- ✅ Visualizações (quando usuário abre produto)
-- ✅ Cliques (quando usuário clica no card)
-- ✅ Pesquisas (quando produto aparece em busca)
-- ✅ Vendas (atualiza automaticamente quando pedido é entregue)
-- ✅ Popularidade (recalculada automaticamente)
-- ============================================

-- 🎯 PRÓXIMOS PASSOS NO FLUTTER:
-- 1. Chamar track_product_view() quando abrir detalhes
-- 2. Chamar track_product_click() quando clicar no card
-- 3. Chamar track_product_search() quando aparecer em pesquisa
-- 4. Usar as funções get_most_popular_products(), etc.
-- ============================================
