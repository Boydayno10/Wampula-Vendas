-- ============================================
-- SCRIPT SQL PARA PEDIDOS - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- Criar o tipo somente se ainda não existir (idempotente)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
        CREATE TYPE order_status AS ENUM (
            'pendente',
            'andamento',
            'entregue',
            'reembolso_solicitado'
        );
    END IF;
END;
$$;

-- 2. Criar ENUM para status de pedidos do vendedor
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'seller_order_status') THEN
        CREATE TYPE seller_order_status AS ENUM (
            'novo',
            'processando',
            'entregue',
            'cancelado'
        );
    END IF;
END;
$$;

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

-- Usuários veem apenas seus pedidos (cliente)
-- Removida referência circular a seller_orders para evitar erro de
-- "infinite recursion" nas políticas RLS.
DROP POLICY IF EXISTS "Usuários veem seus pedidos" ON public.orders;
CREATE POLICY "Usuários veem seus pedidos"
    ON public.orders
    FOR SELECT
    USING (
        auth.uid() = user_id
    );

-- Usuários podem criar seus pedidos
DROP POLICY IF EXISTS "Usuários podem criar pedidos" ON public.orders;
CREATE POLICY "Usuários podem criar pedidos"
    ON public.orders
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Usuários podem atualizar seus pedidos (apenas o cliente dono do pedido)
-- Removida referência circular a seller_orders para evitar erro de
-- "infinite recursion" nas políticas RLS.
DROP POLICY IF EXISTS "Usuários podem atualizar seus pedidos" ON public.orders;
CREATE POLICY "Usuários podem atualizar seus pedidos"
    ON public.orders
    FOR UPDATE
    USING (
        auth.uid() = user_id
    )
    WITH CHECK (
        auth.uid() = user_id
    );

-- 8. Políticas de acesso - ORDER_ITEMS

-- Usuários veem itens de seus pedidos
DROP POLICY IF EXISTS "Usuários veem itens de seus pedidos" ON public.order_items;
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
DROP POLICY IF EXISTS "Usuários podem criar itens" ON public.order_items;
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
DROP POLICY IF EXISTS "Vendedores veem seus pedidos" ON public.seller_orders;
CREATE POLICY "Vendedores veem seus pedidos"
    ON public.seller_orders
    FOR SELECT
    USING (
        -- Vendedor dono do pedido
        auth.uid() = seller_id
        OR
        -- Cliente dono do pedido vinculado (para poder ler e notificar)
        EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = seller_orders.customer_order_id
              AND o.user_id = auth.uid()
        )
    );

-- Sistema pode criar pedidos para vendedores
DROP POLICY IF EXISTS "Sistema pode criar pedidos para vendedores" ON public.seller_orders;
CREATE POLICY "Sistema pode criar pedidos para vendedores"
    ON public.seller_orders
    FOR INSERT
    WITH CHECK (true);

-- Vendedores podem atualizar seus pedidos
DROP POLICY IF EXISTS "Vendedores podem atualizar seus pedidos" ON public.seller_orders;
CREATE POLICY "Vendedores podem atualizar seus pedidos"
    ON public.seller_orders
    FOR UPDATE
    USING (
        -- Vendedor dono do pedido
        auth.uid() = seller_id
        OR
        -- Cliente dono do pedido vinculado (para solicitar reembolso, etc.)
        EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = seller_orders.customer_order_id
              AND o.user_id = auth.uid()
        )
    )
    WITH CHECK (
        auth.uid() = seller_id
        OR EXISTS (
            SELECT 1
            FROM public.orders o
            WHERE o.id = seller_orders.customer_order_id
              AND o.user_id = auth.uid()
        )
    );

-- 10. Criar funções para atualizar updated_at
CREATE OR REPLACE FUNCTION public.handle_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Criar triggers
DROP TRIGGER IF EXISTS set_orders_updated_at ON public.orders;
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
DROP TRIGGER IF EXISTS update_stock_on_seller_order ON public.seller_orders;
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

-- 16. Sincronizar status do pedido do vendedor com o pedido do cliente
--    (resolve problema de RLS: vendedor não consegue atualizar tabela orders diretamente)
CREATE OR REPLACE FUNCTION public.sync_order_status_to_customer()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_customer_status order_status;
    v_order_id TEXT;
BEGIN
    -- Usar sempre o mesmo ID compartilhado entre as tabelas;
    -- se customer_order_id estiver preenchido, ele é a referência do pedido do cliente.
    v_order_id := COALESCE(NEW.customer_order_id, NEW.id);

    -- Mapear status do vendedor -> status do cliente
    IF NEW.status::text = 'novo' THEN
        v_customer_status := 'pendente';
    ELSIF NEW.status::text = 'processando' OR NEW.status::text = 'enviado' THEN
        v_customer_status := 'andamento';
    ELSIF NEW.status::text = 'entregue' THEN
        v_customer_status := 'entregue';
    ELSIF NEW.status::text = 'cancelado' OR NEW.status::text = 'reembolsoSolicitado' THEN
        -- Enum em orders é "reembolso_solicitado"
        v_customer_status := 'reembolso_solicitado';
    ELSE
        -- Qualquer outro caso inesperado não altera o pedido do cliente
        RETURN NEW;
    END IF;

    -- Atualizar status, motivo de reembolso (quando aplicável) e updated_at do pedido do cliente
    UPDATE public.orders
    SET 
        status = v_customer_status,
        -- Quando o vendedor cancelar um pedido, garantimos que o pedido do
        -- cliente fique marcado como "reembolso negado" mesmo que o vendedor
        -- não tenha digitado um motivo específico.
        --
        -- Regras:
        -- - Se o refund_reason já começa com "Negado:", mantemos como está
        -- - Se o vendedor informou um motivo, prefixamos com "Negado: "
        -- - Se não houver motivo, usamos um texto genérico interno
        --   (o app pode optar por não exibir esse texto, apenas o estado).
        refund_reason = CASE
            WHEN NEW.status::text = 'cancelado' THEN
                CASE 
                    WHEN COALESCE(refund_reason, '') LIKE 'Negado:%' THEN refund_reason
                    WHEN NEW.refund_reason IS NOT NULL THEN CONCAT('Negado: ', NEW.refund_reason)
                    ELSE 'Negado: Reembolso negado pelo vendedor'
                END
            ELSE refund_reason
        END,
        updated_at = NOW()
    WHERE id = v_order_id;

    RETURN NEW;
END;
$$;

-- 17. Trigger para sincronizar status sempre que o vendedor atualizar o pedido
DROP TRIGGER IF EXISTS sync_order_status_to_customer ON public.seller_orders;
CREATE TRIGGER sync_order_status_to_customer
    AFTER UPDATE OF status ON public.seller_orders
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION public.sync_order_status_to_customer();

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
