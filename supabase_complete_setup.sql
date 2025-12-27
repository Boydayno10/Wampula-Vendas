-- ============================================
-- SCRIPT CONSOLIDADO - WAMPULA VENDAS
-- ============================================
-- Execute TUDO de uma vez no SQL Editor do Supabase
-- Este script configura todo o banco de dados
-- IDEMPOTENTE: Pode ser executado múltiplas vezes
-- ============================================

-- ============================================
-- PARTE 1: PRODUTOS
-- ============================================

-- Criar tabela de produtos dos vendedores
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
    sizes TEXT[],
    colors TEXT[],
    age_groups TEXT[],
    storage_options TEXT[],
    pant_sizes TEXT[],
    shoe_sizes TEXT[],
    transport_price DECIMAL(10, 2) DEFAULT 50.0 CHECK (transport_price >= 0),
    has_size_option BOOLEAN DEFAULT false,
    has_color_option BOOLEAN DEFAULT false,
    has_age_option BOOLEAN DEFAULT false,
    has_storage_option BOOLEAN DEFAULT false,
    has_pant_size_option BOOLEAN DEFAULT false,
    has_shoe_size_option BOOLEAN DEFAULT false,
    has_location_enabled BOOLEAN DEFAULT false,
    store_latitude DECIMAL(10, 8),
    store_longitude DECIMAL(11, 8),
    store_address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes para recriar
DROP POLICY IF EXISTS "Todos podem ver produtos ativos" ON public.products;
DROP POLICY IF EXISTS "Vendedores podem ver seus produtos" ON public.products;
DROP POLICY IF EXISTS "Vendedores podem criar produtos" ON public.products;
DROP POLICY IF EXISTS "Vendedores podem atualizar seus produtos" ON public.products;
DROP POLICY IF EXISTS "Vendedores podem deletar seus produtos" ON public.products;

-- Criar políticas
CREATE POLICY "Todos podem ver produtos ativos" ON public.products FOR SELECT USING (active = true);
CREATE POLICY "Vendedores podem ver seus produtos" ON public.products FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Vendedores podem criar produtos" ON public.products FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "Vendedores podem atualizar seus produtos" ON public.products FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "Vendedores podem deletar seus produtos" ON public.products FOR DELETE USING (auth.uid() = seller_id);

CREATE OR REPLACE FUNCTION public.handle_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_products_updated_at ON public.products;
CREATE TRIGGER set_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.handle_products_updated_at();

CREATE INDEX IF NOT EXISTS products_seller_id_idx ON public.products(seller_id);
CREATE INDEX IF NOT EXISTS products_category_idx ON public.products(category);
CREATE INDEX IF NOT EXISTS products_active_idx ON public.products(active);
CREATE INDEX IF NOT EXISTS products_sold_count_idx ON public.products(sold_count DESC);
CREATE INDEX IF NOT EXISTS products_popularity_idx ON public.products(popularity DESC);
CREATE INDEX IF NOT EXISTS products_created_at_idx ON public.products(created_at DESC);

-- ============================================
-- PARTE 2: PEDIDOS
-- ============================================

-- Criar tipos ENUM se não existirem
DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('pendente', 'andamento', 'entregue', 'reembolso_solicitado');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE seller_order_status AS ENUM ('novo', 'processando', 'entregue', 'cancelado');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    payment_method TEXT DEFAULT 'M-Pesa',
    status order_status DEFAULT 'pendente',
    delivery_confirmed BOOLEAN DEFAULT false,
    refund_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id TEXT REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    image TEXT NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    size TEXT,
    color TEXT,
    age TEXT,
    storage TEXT,
    pant_size TEXT,
    shoe_size TEXT,
    selected BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.seller_orders (
    id TEXT PRIMARY KEY,
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    customer_order_id TEXT REFERENCES public.orders(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_image TEXT NOT NULL,
    product_price DECIMAL(10, 2) NOT NULL CHECK (product_price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    size TEXT,
    color TEXT,
    age TEXT,
    storage TEXT,
    pant_size TEXT,
    shoe_size TEXT,
    status seller_order_status DEFAULT 'novo',
    refund_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_orders ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes de orders
DROP POLICY IF EXISTS "Usuários veem seus pedidos" ON public.orders;
DROP POLICY IF EXISTS "Usuários podem criar pedidos" ON public.orders;
DROP POLICY IF EXISTS "Usuários podem atualizar seus pedidos" ON public.orders;

-- Remover políticas existentes de order_items
DROP POLICY IF EXISTS "Usuários veem itens de seus pedidos" ON public.order_items;
DROP POLICY IF EXISTS "Usuários podem criar itens" ON public.order_items;

-- Remover políticas existentes de seller_orders
DROP POLICY IF EXISTS "Vendedores veem seus pedidos" ON public.seller_orders;
DROP POLICY IF EXISTS "Sistema pode criar pedidos para vendedores" ON public.seller_orders;
DROP POLICY IF EXISTS "Vendedores podem atualizar seus pedidos" ON public.seller_orders;

-- Criar políticas
CREATE POLICY "Usuários veem seus pedidos" ON public.orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Usuários podem criar pedidos" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Usuários podem atualizar seus pedidos" ON public.orders FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários veem itens de seus pedidos" ON public.order_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_items.order_id AND user_id = auth.uid()));
CREATE POLICY "Usuários podem criar itens" ON public.order_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.orders WHERE id = order_items.order_id AND user_id = auth.uid()));

CREATE POLICY "Vendedores veem seus pedidos" ON public.seller_orders FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Sistema pode criar pedidos para vendedores" ON public.seller_orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Vendedores podem atualizar seus pedidos" ON public.seller_orders FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);

CREATE OR REPLACE FUNCTION public.handle_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_orders_updated_at ON public.orders;
CREATE TRIGGER set_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.handle_orders_updated_at();

CREATE OR REPLACE FUNCTION public.update_product_stock_on_order()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.products
    SET stock = GREATEST(0, stock - NEW.quantity), sold_count = sold_count + NEW.quantity
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_stock_on_seller_order ON public.seller_orders;
CREATE TRIGGER update_stock_on_seller_order AFTER INSERT ON public.seller_orders FOR EACH ROW WHEN (NEW.product_id IS NOT NULL) EXECUTE FUNCTION public.update_product_stock_on_order();

CREATE INDEX IF NOT EXISTS orders_user_id_idx ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON public.orders(status);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS order_items_order_id_idx ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS order_items_product_id_idx ON public.order_items(product_id);
CREATE INDEX IF NOT EXISTS seller_orders_seller_id_idx ON public.seller_orders(seller_id);
CREATE INDEX IF NOT EXISTS seller_orders_status_idx ON public.seller_orders(status);
CREATE INDEX IF NOT EXISTS seller_orders_created_at_idx ON public.seller_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS seller_orders_customer_order_id_idx ON public.seller_orders(customer_order_id);

-- ============================================
-- PARTE 3: NOTIFICAÇÕES
-- ============================================

DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM ('pedido', 'entrega', 'pagamento', 'produto', 'promocao', 'sistema');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type notification_type DEFAULT 'sistema',
    read BOOLEAN DEFAULT false,
    action_url TEXT,
    related_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes
DROP POLICY IF EXISTS "Usuários veem suas notificações" ON public.notifications;
DROP POLICY IF EXISTS "Sistema pode criar notificações" ON public.notifications;
DROP POLICY IF EXISTS "Usuários podem atualizar suas notificações" ON public.notifications;
DROP POLICY IF EXISTS "Usuários podem deletar suas notificações" ON public.notifications;

-- Criar políticas
CREATE POLICY "Usuários veem suas notificações" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Sistema pode criar notificações" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Usuários podem atualizar suas notificações" ON public.notifications FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Usuários podem deletar suas notificações" ON public.notifications FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_read_idx ON public.notifications(read);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_type_idx ON public.notifications(type);

CREATE OR REPLACE FUNCTION public.count_unread_notifications(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*)::INTEGER FROM public.notifications WHERE user_id = p_user_id AND read = false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications SET read = true WHERE user_id = p_user_id AND read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.notify_new_order()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, related_id)
    VALUES (NEW.user_id, 'Pedido confirmado', 'Seu pedido ' || NEW.id || ' foi confirmado e está sendo preparado', 'pedido', NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS notify_on_new_order ON public.orders;
CREATE TRIGGER notify_on_new_order AFTER INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.notify_new_order();

CREATE OR REPLACE FUNCTION public.notify_seller_new_order()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, related_id)
    VALUES (NEW.seller_id, 'Novo pedido!', 'Você recebeu um pedido de ' || NEW.product_name || ' (x' || NEW.quantity || ')', 'pedido', NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS notify_seller_on_new_order ON public.seller_orders;
CREATE TRIGGER notify_seller_on_new_order AFTER INSERT ON public.seller_orders FOR EACH ROW EXECUTE FUNCTION public.notify_seller_new_order();

CREATE OR REPLACE FUNCTION public.notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_message TEXT;
BEGIN
    IF NEW.status = 'entregue' AND OLD.status != 'entregue' THEN
        SELECT user_id INTO v_user_id FROM public.orders WHERE id = NEW.customer_order_id;
        IF v_user_id IS NOT NULL THEN
            v_message := 'Seu pedido ' || NEW.customer_order_id || ' foi entregue!';
            INSERT INTO public.notifications (user_id, title, message, type, related_id)
            VALUES (v_user_id, 'Pedido entregue', v_message, 'entrega', NEW.customer_order_id);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS notify_on_order_status_change ON public.seller_orders;
CREATE TRIGGER notify_on_order_status_change AFTER UPDATE OF status ON public.seller_orders FOR EACH ROW WHEN (NEW.status IS DISTINCT FROM OLD.status) EXECUTE FUNCTION public.notify_order_status_change();

-- ============================================
-- PARTE 4: TRANSAÇÕES FINANCEIRAS
-- ============================================

DO $$ BEGIN
    CREATE TYPE transaction_type AS ENUM ('venda', 'comissao', 'saque', 'estorno');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.seller_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    type transaction_type NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    description TEXT NOT NULL,
    order_id TEXT REFERENCES public.seller_orders(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.seller_balances (
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    available_balance DECIMAL(10, 2) DEFAULT 0 CHECK (available_balance >= 0),
    pending_balance DECIMAL(10, 2) DEFAULT 0 CHECK (pending_balance >= 0),
    total_earnings DECIMAL(10, 2) DEFAULT 0 CHECK (total_earnings >= 0),
    total_withdrawn DECIMAL(10, 2) DEFAULT 0 CHECK (total_withdrawn >= 0),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.seller_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_balances ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes
DROP POLICY IF EXISTS "Vendedores veem suas transações" ON public.seller_transactions;
DROP POLICY IF EXISTS "Sistema pode criar transações" ON public.seller_transactions;
DROP POLICY IF EXISTS "Vendedores veem seu saldo" ON public.seller_balances;
DROP POLICY IF EXISTS "Sistema pode atualizar saldos" ON public.seller_balances;
DROP POLICY IF EXISTS "Sistema pode criar saldos" ON public.seller_balances;

-- Criar políticas
CREATE POLICY "Vendedores veem suas transações" ON public.seller_transactions FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Sistema pode criar transações" ON public.seller_transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Vendedores veem seu saldo" ON public.seller_balances FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Sistema pode atualizar saldos" ON public.seller_balances FOR UPDATE WITH CHECK (true);
CREATE POLICY "Sistema pode criar saldos" ON public.seller_balances FOR INSERT WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.register_sale_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_commission_rate DECIMAL := 0.10;
    v_commission_amount DECIMAL;
    v_seller_amount DECIMAL;
BEGIN
    IF NEW.status = 'entregue' AND OLD.status != 'entregue' THEN
        v_commission_amount := NEW.total * v_commission_rate;
        v_seller_amount := NEW.total - v_commission_amount;
        
        INSERT INTO public.seller_transactions (seller_id, type, amount, description, order_id)
        VALUES (NEW.seller_id, 'venda', NEW.total, 'Venda: ' || NEW.product_name || ' x' || NEW.quantity, NEW.id);
        
        INSERT INTO public.seller_transactions (seller_id, type, amount, description, order_id)
        VALUES (NEW.seller_id, 'comissao', v_commission_amount, 'Comissão da plataforma (10%)', NEW.id);
        
        INSERT INTO public.seller_balances (seller_id, available_balance, total_earnings)
        VALUES (NEW.seller_id, v_seller_amount, v_seller_amount)
        ON CONFLICT (seller_id) 
        DO UPDATE SET
            available_balance = seller_balances.available_balance + v_seller_amount,
            total_earnings = seller_balances.total_earnings + v_seller_amount,
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS register_sale_on_delivery ON public.seller_orders;
CREATE TRIGGER register_sale_on_delivery AFTER UPDATE OF status ON public.seller_orders FOR EACH ROW WHEN (NEW.status = 'entregue' AND OLD.status IS DISTINCT FROM 'entregue') EXECUTE FUNCTION public.register_sale_transaction();

CREATE OR REPLACE FUNCTION public.process_withdrawal(p_seller_id UUID, p_amount DECIMAL)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_balance DECIMAL;
BEGIN
    SELECT available_balance INTO v_current_balance FROM public.seller_balances WHERE seller_id = p_seller_id;
    IF v_current_balance IS NULL OR v_current_balance < p_amount THEN
        RETURN false;
    END IF;
    INSERT INTO public.seller_transactions (seller_id, type, amount, description)
    VALUES (p_seller_id, 'saque', p_amount, 'Saque realizado');
    UPDATE public.seller_balances
    SET available_balance = available_balance - p_amount, total_withdrawn = total_withdrawn + p_amount, updated_at = NOW()
    WHERE seller_id = p_seller_id;
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_seller_finance(p_seller_id UUID)
RETURNS TABLE (
    available_balance DECIMAL,
    pending_balance DECIMAL,
    total_earnings DECIMAL,
    total_withdrawn DECIMAL,
    total_sales BIGINT,
    this_month_sales DECIMAL,
    last_month_sales DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(sb.available_balance, 0),
        COALESCE(sb.pending_balance, 0),
        COALESCE(sb.total_earnings, 0),
        COALESCE(sb.total_withdrawn, 0),
        COUNT(DISTINCT so.id),
        COALESCE(SUM(CASE WHEN so.delivered_at >= date_trunc('month', CURRENT_DATE) THEN so.total ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN so.delivered_at >= date_trunc('month', CURRENT_DATE - interval '1 month') AND so.delivered_at < date_trunc('month', CURRENT_DATE) THEN so.total ELSE 0 END), 0)
    FROM public.seller_balances sb
    LEFT JOIN public.seller_orders so ON so.seller_id = sb.seller_id AND so.status = 'entregue'
    WHERE sb.seller_id = p_seller_id
    GROUP BY sb.available_balance, sb.pending_balance, sb.total_earnings, sb.total_withdrawn;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE INDEX IF NOT EXISTS seller_transactions_seller_id_idx ON public.seller_transactions(seller_id);
CREATE INDEX IF NOT EXISTS seller_transactions_type_idx ON public.seller_transactions(type);
CREATE INDEX IF NOT EXISTS seller_transactions_created_at_idx ON public.seller_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS seller_transactions_order_id_idx ON public.seller_transactions(order_id);

-- ============================================
-- ✅ SCRIPT EXECUTADO COM SUCESSO!
-- ============================================
-- Próximos passos:
-- 1. Verifique as tabelas criadas no Table Editor
-- 2. Teste criando um produto
-- 3. Teste fazendo um pedido
-- 4. Verifique se as notificações são criadas automaticamente
-- 
-- Este script é IDEMPOTENTE e pode ser executado
-- múltiplas vezes sem causar erros!
-- ============================================
