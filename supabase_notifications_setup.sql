-- ============================================
-- SCRIPT SQL PARA NOTIFICAÇÕES - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Criar ENUM para tipos de notificação
CREATE TYPE notification_type AS ENUM (
    'pedido',
    'entrega',
    'pagamento',
    'produto',
    'promocao',
    'sistema'
);

-- 2. Criar tabela de notificações
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    
    -- Conteúdo da notificação
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type notification_type DEFAULT 'sistema',
    
    -- Status
    read BOOLEAN DEFAULT false,
    
    -- Metadados (opcional - para ações específicas)
    action_url TEXT, -- URL/rota para navegar quando clicar
    related_id TEXT, -- ID do pedido, produto, etc relacionado
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Habilitar Row Level Security (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 4. Criar políticas de acesso

-- Usuários veem apenas suas notificações
CREATE POLICY "Usuários veem suas notificações"
    ON public.notifications
    FOR SELECT
    USING (auth.uid() = user_id);

-- Sistema pode criar notificações para qualquer usuário
CREATE POLICY "Sistema pode criar notificações"
    ON public.notifications
    FOR INSERT
    WITH CHECK (true);

-- Usuários podem atualizar suas notificações (marcar como lida)
CREATE POLICY "Usuários podem atualizar suas notificações"
    ON public.notifications
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Usuários podem deletar suas notificações
CREATE POLICY "Usuários podem deletar suas notificações"
    ON public.notifications
    FOR DELETE
    USING (auth.uid() = user_id);

-- 5. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_read_idx ON public.notifications(read);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_type_idx ON public.notifications(type);

-- 6. Criar função para contar notificações não lidas
CREATE OR REPLACE FUNCTION public.count_unread_notifications(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.notifications
        WHERE user_id = p_user_id AND read = false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Criar função para marcar todas como lidas
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications
    SET read = true
    WHERE user_id = p_user_id AND read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Criar função para criar notificação de novo pedido (automatizada)
CREATE OR REPLACE FUNCTION public.notify_new_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Notificar o cliente
    INSERT INTO public.notifications (user_id, title, message, type, related_id)
    VALUES (
        NEW.user_id,
        'Pedido confirmado',
        'Seu pedido ' || NEW.id || ' foi confirmado e está sendo preparado',
        'pedido',
        NEW.id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Criar trigger para notificar novo pedido
CREATE TRIGGER notify_on_new_order
    AFTER INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_new_order();

-- 10. Criar função para notificar vendedor de novo pedido
CREATE OR REPLACE FUNCTION public.notify_seller_new_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Notificar o vendedor
    INSERT INTO public.notifications (user_id, title, message, type, related_id)
    VALUES (
        NEW.seller_id,
        'Novo pedido!',
        'Você recebeu um pedido de ' || NEW.product_name || ' (x' || NEW.quantity || ')',
        'pedido',
        NEW.id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Criar trigger para notificar vendedor
CREATE TRIGGER notify_seller_on_new_order
    AFTER INSERT ON public.seller_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_seller_new_order();

-- 12. Criar função para notificar atualização de status
CREATE OR REPLACE FUNCTION public.notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_message TEXT;
BEGIN
    -- Se for pedido do vendedor que mudou para 'entregue'
    IF NEW.status = 'entregue' AND OLD.status != 'entregue' THEN
        -- Buscar user_id do pedido do cliente
        SELECT user_id INTO v_user_id
        FROM public.orders
        WHERE id = NEW.customer_order_id;
        
        IF v_user_id IS NOT NULL THEN
            v_message := 'Seu pedido ' || NEW.customer_order_id || ' foi entregue!';
            
            INSERT INTO public.notifications (user_id, title, message, type, related_id)
            VALUES (
                v_user_id,
                'Pedido entregue',
                v_message,
                'entrega',
                NEW.customer_order_id
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 13. Criar trigger para notificar mudança de status
CREATE TRIGGER notify_on_order_status_change
    AFTER UPDATE OF status ON public.seller_orders
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION public.notify_order_status_change();

-- 14. Criar view para estatísticas de notificações
CREATE OR REPLACE VIEW public.notification_stats AS
SELECT 
    user_id,
    COUNT(*) as total_notifications,
    COUNT(CASE WHEN read = false THEN 1 END) as unread_count,
    COUNT(CASE WHEN type = 'pedido' THEN 1 END) as order_notifications,
    COUNT(CASE WHEN type = 'entrega' THEN 1 END) as delivery_notifications
FROM public.notifications
GROUP BY user_id;

-- ============================================
-- NOTAS IMPORTANTES:
-- ============================================
-- 1. Notificações são criadas automaticamente via triggers
-- 2. Cliente recebe notificação ao fazer pedido
-- 3. Vendedor recebe notificação ao receber pedido
-- 4. Cliente é notificado quando pedido é entregue
-- 5. RLS garante privacidade das notificações
-- 6. Função count_unread_notifications facilita contagem
-- ============================================

-- VERIFICAÇÃO (OPCIONAL)
-- SELECT * FROM public.notifications;
-- SELECT * FROM public.notification_stats;
-- SELECT public.count_unread_notifications('user-uuid-here');
