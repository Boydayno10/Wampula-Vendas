-- ============================================
-- SCRIPT SQL PARA CARRINHO - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Criar tabela de itens do carrinho
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Habilitar Row Level Security (RLS)
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- 3. Políticas de acesso - CART_ITEMS

-- Usuário vê apenas itens do próprio carrinho
DROP POLICY IF EXISTS "Usuários veem seus itens de carrinho" ON public.cart_items;
CREATE POLICY "Usuários veem seus itens de carrinho"
    ON public.cart_items
    FOR SELECT
    USING (auth.uid() = user_id);

-- Usuário pode adicionar itens ao próprio carrinho
DROP POLICY IF EXISTS "Usuários podem adicionar itens ao carrinho" ON public.cart_items;
CREATE POLICY "Usuários podem adicionar itens ao carrinho"
    ON public.cart_items
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Usuário pode atualizar itens do próprio carrinho
DROP POLICY IF EXISTS "Usuários podem atualizar itens do carrinho" ON public.cart_items;
CREATE POLICY "Usuários podem atualizar itens do carrinho"
    ON public.cart_items
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Usuário pode remover itens do próprio carrinho
DROP POLICY IF EXISTS "Usuários podem remover itens do carrinho" ON public.cart_items;
CREATE POLICY "Usuários podem remover itens do carrinho"
    ON public.cart_items
    FOR DELETE
    USING (auth.uid() = user_id);

-- 4. Função para atualizar updated_at
CREATE OR REPLACE FUNCTION public.handle_cart_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger de updated_at
DROP TRIGGER IF EXISTS set_cart_items_updated_at ON public.cart_items;
CREATE TRIGGER set_cart_items_updated_at
    BEFORE UPDATE ON public.cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_cart_items_updated_at();

-- ============================================
-- ✅ PRONTO! Agora hot reload o app
-- ============================================
