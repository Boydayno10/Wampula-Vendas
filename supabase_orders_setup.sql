-- ============================================
-- SCRIPT SQL PARA PEDIDOS - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Criar ENUM para status de pedidos do cliente
CREATE TYPE order_status AS ENUM (
    'pendente',
    'andamento',
    'entregue',
    'reembolso_solicitado'
);

-- 2. Criar ENUM para status de pedidos do vendedor
CREATE TYPE seller_order_status AS ENUM (
    'novo',
    'processando',
    'entregue',
    'cancelado'
);

-- 3. Criar tabela de pedidos do cliente
CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY, -- WP-000001
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    
    -- Informações do pedido
    total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    payment_method TEXT DEFAULT 'M-Pesa',
    status order_status DEFAULT 'pendente',
    
    -- Confirmação e reembolso
    delivery_confirmed BOOLEAN DEFAULT false,
    refund_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Criar tabela de itens do pedido
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id TEXT REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    
    -- Detalhes do item
    name TEXT NOT NULL,
    image TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    
    -- Opções selecionadas
    size TEXT,
    color TEXT,
    age TEXT,
    storage TEXT,
    pant_size TEXT,
    shoe_size TEXT,
    
    selected BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Criar tabela de pedidos do vendedor
CREATE TABLE IF NOT EXISTS public.seller_orders (
    id TEXT PRIMARY KEY, -- SO-timestamp
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    customer_order_id TEXT REFERENCES public.orders(id) ON DELETE SET NULL,
    
    -- Informações do produto
    product_name TEXT NOT NULL,
    product_image TEXT NOT NULL,
    product_price DECIMAL(10, 2) NOT NULL CHECK (product_price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    
    -- Informações do cliente
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    
    -- Opções do produto
    size TEXT,
    color TEXT,
    age TEXT,
    storage TEXT,
    pant_size TEXT,
    shoe_size TEXT,
    
    -- Status e timestamps
    status seller_order_status DEFAULT 'novo',
    refund_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE
);

-- 6. Habilitar Row Level Security (RLS)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_orders ENABLE ROW LEVEL SECURITY;

-- 7. Políticas de acesso - ORDERS

-- Usuários veem apenas seus pedidos
CREATE POLICY "Usuários veem seus pedidos"
    ON public.orders
    FOR SELECT
    USING (auth.uid() = user_id);

-- Usuários podem criar seus pedidos
CREATE POLICY "Usuários podem criar pedidos"
    ON public.orders
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Usuários podem atualizar seus pedidos
CREATE POLICY "Usuários podem atualizar seus pedidos"
    ON public.orders
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 8. Políticas de acesso - ORDER_ITEMS

-- Usuários veem itens de seus pedidos
CREATE POLICY "Usuários veem itens de seus pedidos"
    ON public.order_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders 
            WHERE id = order_items.order_id 
            AND user_id = auth.uid()
        )
    );

-- Usuários podem criar itens em seus pedidos
CREATE POLICY "Usuários podem criar itens"
    ON public.order_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.orders 
            WHERE id = order_items.order_id 
            AND user_id = auth.uid()
        )
    );

-- 9. Políticas de acesso - SELLER_ORDERS

-- Vendedores veem apenas seus pedidos
CREATE POLICY "Vendedores veem seus pedidos"
    ON public.seller_orders
    FOR SELECT
    USING (auth.uid() = seller_id);

-- Sistema pode criar pedidos para vendedores
CREATE POLICY "Sistema pode criar pedidos para vendedores"
    ON public.seller_orders
    FOR INSERT
    WITH CHECK (true);

-- Vendedores podem atualizar seus pedidos
CREATE POLICY "Vendedores podem atualizar seus pedidos"
    ON public.seller_orders
    FOR UPDATE
    USING (auth.uid() = seller_id)
    WITH CHECK (auth.uid() = seller_id);

-- 10. Criar funções para atualizar updated_at
CREATE OR REPLACE FUNCTION public.handle_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Criar triggers
CREATE TRIGGER set_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_orders_updated_at();

-- 12. Criar função para atualizar estoque ao criar pedido
CREATE OR REPLACE FUNCTION public.update_product_stock_on_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Atualizar estoque do produto
    UPDATE public.products
    SET 
        stock = GREATEST(0, stock - NEW.quantity),
        sold_count = sold_count + NEW.quantity
    WHERE id = NEW.product_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 13. Criar trigger para atualizar estoque
CREATE TRIGGER update_stock_on_seller_order
    AFTER INSERT ON public.seller_orders
    FOR EACH ROW
    WHEN (NEW.product_id IS NOT NULL)
    EXECUTE FUNCTION public.update_product_stock_on_order();

-- 14. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS orders_user_id_idx ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON public.orders(status);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON public.orders(created_at DESC);

CREATE INDEX IF NOT EXISTS order_items_order_id_idx ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS order_items_product_id_idx ON public.order_items(product_id);

CREATE INDEX IF NOT EXISTS seller_orders_seller_id_idx ON public.seller_orders(seller_id);
CREATE INDEX IF NOT EXISTS seller_orders_status_idx ON public.seller_orders(status);
CREATE INDEX IF NOT EXISTS seller_orders_created_at_idx ON public.seller_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS seller_orders_customer_order_id_idx ON public.seller_orders(customer_order_id);

-- 15. Criar view para estatísticas de pedidos do vendedor
CREATE OR REPLACE VIEW public.seller_order_stats AS
SELECT 
    seller_id,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN status = 'novo' THEN 1 END) as new_orders,
    COUNT(CASE WHEN status = 'processando' THEN 1 END) as processing_orders,
    COUNT(CASE WHEN status = 'entregue' THEN 1 END) as delivered_orders,
    SUM(total) as total_revenue,
    SUM(CASE WHEN status = 'entregue' THEN total ELSE 0 END) as delivered_revenue
FROM public.seller_orders
GROUP BY seller_id;

-- ============================================
-- NOTAS IMPORTANTES:
-- ============================================
-- 1. Pedidos do cliente e vendedor são separados
-- 2. Estoque é atualizado automaticamente via trigger
-- 3. RLS garante que cada usuário veja apenas seus dados
-- 4. customer_order_id vincula pedidos do vendedor ao cliente
-- 5. Status são ENUMs para garantir valores válidos
-- ============================================

-- VERIFICAÇÃO (OPCIONAL)
-- SELECT * FROM public.orders;
-- SELECT * FROM public.seller_orders;
-- SELECT * FROM public.seller_order_stats;
