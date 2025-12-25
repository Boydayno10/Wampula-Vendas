-- ============================================
-- SCRIPT SQL PARA PRODUTOS - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Criar tabela de produtos dos vendedores
CREATE TABLE IF NOT EXISTS public.products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    seller_store_name TEXT NOT NULL,
    name TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    old_price DECIMAL(10, 2) CHECK (old_price >= 0),
    image TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    stock INTEGER DEFAULT 0 CHECK (stock >= 0),
    active BOOLEAN DEFAULT true,
    sold_count INTEGER DEFAULT 0 CHECK (sold_count >= 0),
    popularity DECIMAL(5, 2) DEFAULT 0 CHECK (popularity >= 0 AND popularity <= 100),
    
    -- Opções do produto
    sizes TEXT[], -- Array de tamanhos (S, M, L, XL)
    colors TEXT[], -- Array de cores
    age_groups TEXT[], -- Array de faixas etárias (1-3M, 4-6M)
    storage_options TEXT[], -- Array de armazenamento (64GB, 128GB)
    pant_sizes TEXT[], -- Array de tamanhos de calças (28, 30, 32)
    shoe_sizes TEXT[], -- Array de tamanhos de calçados (36, 37, 38)
    transport_price DECIMAL(10, 2) DEFAULT 50.0 CHECK (transport_price >= 0),
    
    -- Flags de opções
    has_size_option BOOLEAN DEFAULT false,
    has_color_option BOOLEAN DEFAULT false,
    has_age_option BOOLEAN DEFAULT false,
    has_storage_option BOOLEAN DEFAULT false,
    has_pant_size_option BOOLEAN DEFAULT false,
    has_shoe_size_option BOOLEAN DEFAULT false,
    
    -- Localização da loja
    has_location_enabled BOOLEAN DEFAULT false,
    store_latitude DECIMAL(10, 8),
    store_longitude DECIMAL(11, 8),
    store_address TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Habilitar Row Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 3. Criar políticas de acesso

-- Política: Todos podem ver produtos ativos
CREATE POLICY "Todos podem ver produtos ativos"
    ON public.products
    FOR SELECT
    USING (active = true);

-- Política: Vendedores podem ver todos os seus produtos
CREATE POLICY "Vendedores podem ver seus produtos"
    ON public.products
    FOR SELECT
    USING (auth.uid() = seller_id);

-- Política: Vendedores podem criar seus produtos
CREATE POLICY "Vendedores podem criar produtos"
    ON public.products
    FOR INSERT
    WITH CHECK (auth.uid() = seller_id);

-- Política: Vendedores podem atualizar seus produtos
CREATE POLICY "Vendedores podem atualizar seus produtos"
    ON public.products
    FOR UPDATE
    USING (auth.uid() = seller_id)
    WITH CHECK (auth.uid() = seller_id);

-- Política: Vendedores podem deletar seus produtos
CREATE POLICY "Vendedores podem deletar seus produtos"
    ON public.products
    FOR DELETE
    USING (auth.uid() = seller_id);

-- 4. Criar função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Criar trigger para atualizar updated_at
CREATE TRIGGER set_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_products_updated_at();

-- 6. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS products_seller_id_idx ON public.products(seller_id);
CREATE INDEX IF NOT EXISTS products_category_idx ON public.products(category);
CREATE INDEX IF NOT EXISTS products_active_idx ON public.products(active);
CREATE INDEX IF NOT EXISTS products_sold_count_idx ON public.products(sold_count DESC);
CREATE INDEX IF NOT EXISTS products_popularity_idx ON public.products(popularity DESC);
CREATE INDEX IF NOT EXISTS products_created_at_idx ON public.products(created_at DESC);

-- 7. Criar view para produtos mais vendidos
CREATE OR REPLACE VIEW public.top_selling_products AS
SELECT 
    id,
    seller_id,
    seller_store_name,
    name,
    price,
    old_price,
    image,
    category,
    stock,
    sold_count,
    popularity
FROM public.products
WHERE active = true AND stock > 0
ORDER BY sold_count DESC, popularity DESC
LIMIT 20;

-- 8. Criar função para buscar produtos por categoria
CREATE OR REPLACE FUNCTION public.get_products_by_category(category_name TEXT)
RETURNS TABLE (
    id UUID,
    seller_id UUID,
    seller_store_name TEXT,
    name TEXT,
    price DECIMAL,
    old_price DECIMAL,
    image TEXT,
    category TEXT,
    stock INTEGER,
    sold_count INTEGER,
    popularity DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.seller_id,
        p.seller_store_name,
        p.name,
        p.price,
        p.old_price,
        p.image,
        p.category,
        p.stock,
        p.sold_count,
        p.popularity
    FROM public.products p
    WHERE p.active = true 
        AND p.stock > 0 
        AND p.category = category_name
    ORDER BY p.popularity DESC, p.sold_count DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- NOTAS IMPORTANTES:
-- ============================================
-- 1. Produtos só são visíveis quando active = true
-- 2. Vendedores só podem gerenciar seus próprios produtos
-- 3. RLS garante segurança dos dados
-- 4. Índices otimizam buscas por categoria, vendedor e popularidade
-- 5. Arrays são usados para opções (tamanhos, cores, etc.)
-- ============================================

-- VERIFICAÇÃO (OPCIONAL)
-- SELECT * FROM public.products;
-- SELECT * FROM public.top_selling_products;
