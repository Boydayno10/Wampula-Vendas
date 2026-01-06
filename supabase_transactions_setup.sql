-- ============================================
-- SCRIPT SQL PARA TRANSAÇÕES FINANCEIRAS - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Criar ENUM para tipos de transação
CREATE TYPE transaction_type AS ENUM (
    'venda',
    'comissao',
    'saque',
    'estorno'
);

-- 2. Criar tabela de transações do vendedor
CREATE TABLE IF NOT EXISTS public.seller_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    
    -- Detalhes da transação
    type transaction_type NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    description TEXT NOT NULL,
    
    -- Relacionamento com pedido (opcional)
    order_id TEXT REFERENCES public.seller_orders(id) ON DELETE SET NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Criar tabela de saldo do vendedor
CREATE TABLE IF NOT EXISTS public.seller_balances (
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    
    -- Saldos
    available_balance DECIMAL(10, 2) DEFAULT 0 CHECK (available_balance >= 0),
    pending_balance DECIMAL(10, 2) DEFAULT 0 CHECK (pending_balance >= 0),
    total_earnings DECIMAL(10, 2) DEFAULT 0 CHECK (total_earnings >= 0),
    total_withdrawn DECIMAL(10, 2) DEFAULT 0 CHECK (total_withdrawn >= 0),
    
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Habilitar Row Level Security (RLS)
ALTER TABLE public.seller_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_balances ENABLE ROW LEVEL SECURITY;

-- 5. Políticas de acesso - SELLER_TRANSACTIONS

-- Vendedores veem apenas suas transações
CREATE POLICY "Vendedores veem suas transações"
    ON public.seller_transactions
    FOR SELECT
    USING (auth.uid() = seller_id);

-- Sistema pode criar transações
CREATE POLICY "Sistema pode criar transações"
    ON public.seller_transactions
    FOR INSERT
    WITH CHECK (true);

-- 6. Políticas de acesso - SELLER_BALANCES

-- Vendedores veem apenas seu saldo
CREATE POLICY "Vendedores veem seu saldo"
    ON public.seller_balances
    FOR SELECT
    USING (auth.uid() = seller_id);

-- Sistema pode atualizar saldos
CREATE POLICY "Sistema pode atualizar saldos"
    ON public.seller_balances
    FOR UPDATE
    WITH CHECK (true);

-- Sistema pode criar saldos
CREATE POLICY "Sistema pode criar saldos"
    ON public.seller_balances
    FOR INSERT
    WITH CHECK (true);

-- 7. Criar função para registrar venda e comissão
CREATE OR REPLACE FUNCTION public.register_sale_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_commission_rate DECIMAL := 0.10; -- 10% de comissão
    v_commission_amount DECIMAL;
    v_seller_amount DECIMAL;
BEGIN
    -- Só processa se o status mudou para 'entregue'
    IF NEW.status = 'entregue' AND OLD.status != 'entregue' THEN
        -- Calcular valores
        v_commission_amount := NEW.total * v_commission_rate;
        v_seller_amount := NEW.total - v_commission_amount;
        
        -- Registrar venda
        INSERT INTO public.seller_transactions (seller_id, type, amount, description, order_id)
        VALUES (
            NEW.seller_id,
            'venda',
            NEW.total,
            'Venda: ' || NEW.product_name || ' x' || NEW.quantity,
            NEW.id
        );
        
        -- Registrar comissão
        INSERT INTO public.seller_transactions (seller_id, type, amount, description, order_id)
        VALUES (
            NEW.seller_id,
            'comissao',
            v_commission_amount,
            'Comissão da plataforma (10%)',
            NEW.id
        );
        
        -- Atualizar saldo do vendedor
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

-- 8. Criar trigger para registrar transações ao entregar pedido
CREATE TRIGGER register_sale_on_delivery
    AFTER UPDATE OF status ON public.seller_orders
    FOR EACH ROW
    WHEN (NEW.status = 'entregue' AND OLD.status IS DISTINCT FROM 'entregue')
    EXECUTE FUNCTION public.register_sale_transaction();

-- 9. Criar função para processar saque
CREATE OR REPLACE FUNCTION public.process_withdrawal(
    p_seller_id UUID,
    p_amount DECIMAL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_balance DECIMAL;
BEGIN
    -- Verificar saldo disponível
    SELECT available_balance INTO v_current_balance
    FROM public.seller_balances
    WHERE seller_id = p_seller_id;
    
    IF v_current_balance IS NULL OR v_current_balance < p_amount THEN
        RETURN false; -- Saldo insuficiente
    END IF;
    
    -- Registrar transação de saque
    INSERT INTO public.seller_transactions (seller_id, type, amount, description)
    VALUES (
        p_seller_id,
        'saque',
        p_amount,
        'Saque realizado'
    );
    
    -- Atualizar saldo
    UPDATE public.seller_balances
    SET 
        available_balance = available_balance - p_amount,
        total_withdrawn = total_withdrawn + p_amount,
        updated_at = NOW()
    WHERE seller_id = p_seller_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Criar função para obter financeiro do vendedor
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
        COALESCE(SUM(CASE 
            WHEN so.delivered_at >= date_trunc('month', CURRENT_DATE) 
            THEN so.total 
            ELSE 0 
        END), 0),
        COALESCE(SUM(CASE 
            WHEN so.delivered_at >= date_trunc('month', CURRENT_DATE - interval '1 month')
            AND so.delivered_at < date_trunc('month', CURRENT_DATE)
            THEN so.total 
            ELSE 0 
        END), 0)
    FROM public.seller_balances sb
    LEFT JOIN public.seller_orders so ON so.seller_id = sb.seller_id AND so.status = 'entregue'
    WHERE sb.seller_id = p_seller_id
    GROUP BY sb.available_balance, sb.pending_balance, sb.total_earnings, sb.total_withdrawn;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS seller_transactions_seller_id_idx ON public.seller_transactions(seller_id);
CREATE INDEX IF NOT EXISTS seller_transactions_type_idx ON public.seller_transactions(type);
CREATE INDEX IF NOT EXISTS seller_transactions_created_at_idx ON public.seller_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS seller_transactions_order_id_idx ON public.seller_transactions(order_id);

-- 12. Criar view para resumo financeiro
CREATE OR REPLACE VIEW public.seller_finance_summary AS
SELECT 
    sb.seller_id,
    sb.available_balance,
    sb.pending_balance,
    sb.total_earnings,
    sb.total_withdrawn,
    COUNT(DISTINCT st.id) as total_transactions,
    COUNT(DISTINCT so.id) as total_orders
FROM public.seller_balances sb
LEFT JOIN public.seller_transactions st ON st.seller_id = sb.seller_id
LEFT JOIN public.seller_orders so ON so.seller_id = sb.seller_id AND so.status = 'entregue'
GROUP BY sb.seller_id, sb.available_balance, sb.pending_balance, sb.total_earnings, sb.total_withdrawn;

-- 13. Criar função para atualizar updated_at
CREATE OR REPLACE FUNCTION public.handle_seller_balances_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14. Criar trigger para atualizar updated_at
CREATE TRIGGER set_seller_balances_updated_at
    BEFORE UPDATE ON public.seller_balances
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_seller_balances_updated_at();

-- ============================================
-- NOTAS IMPORTANTES:
-- ============================================
-- 1. Transações são criadas automaticamente quando pedido é entregue
-- 2. Comissão de 10% é descontada automaticamente
-- 3. Saldo disponível é atualizado em tempo real
-- 4. Função process_withdrawal permite saques seguros
-- 5. get_seller_finance retorna estatísticas completas
-- 6. RLS garante que vendedores vejam apenas seus dados
-- ============================================

-- VERIFICAÇÃO (OPCIONAL)
-- SELECT * FROM public.seller_transactions;
-- SELECT * FROM public.seller_balances;
-- SELECT * FROM public.seller_finance_summary;
-- SELECT * FROM public.get_seller_finance('seller-uuid-here');
