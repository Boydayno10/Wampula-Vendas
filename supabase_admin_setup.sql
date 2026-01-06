-- ============================================
-- ADMIN SETUP - WAMPULA VENDAS
-- ============================================
-- Execute este script NO SQL EDITOR do Supabase (Dashboard)
-- Ele cria uma tabela de administradores e dá acesso completo
-- aos admins em todas as tabelas principais do app.
-- ============================================

-- 1) Tabela de administradores
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id)
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Qualquer usuário pode ver SE ele mesmo é admin (para o painel checar)
DROP POLICY IF EXISTS "admin_users_self_read" ON public.admin_users;
CREATE POLICY "admin_users_self_read"
ON public.admin_users
FOR SELECT
USING (auth.uid() = user_id);

-- Somente admins podem gerenciar a lista de admins
DROP POLICY IF EXISTS "admin_users_manage" ON public.admin_users;
CREATE POLICY "admin_users_manage"
ON public.admin_users
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users au
    WHERE au.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.admin_users au
    WHERE au.user_id = auth.uid()
  )
);

-- ============================================
-- 2) Dar superpoderes aos admins nas tabelas principais
-- ============================================
-- Regra geral: se auth.uid() estiver em admin_users,
-- ele pode ver/alterar/apagar qualquer linha da tabela.

-- Helper condition reutilizável
-- (Postgres não aceita macro aqui, então repetimos a condição)

-- Perfis de usuários
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos perfis" ON public.profiles;
CREATE POLICY "Admins gerenciam todos perfis"
ON public.profiles
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Produtos
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos produtos" ON public.products;
CREATE POLICY "Admins gerenciam todos produtos"
ON public.products
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Publicações de clientes
ALTER TABLE public.client_publications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas publicacoes" ON public.client_publications;
CREATE POLICY "Admins gerenciam todas publicacoes"
ON public.client_publications
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Pedidos e itens de pedido
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos pedidos" ON public.orders;
CREATE POLICY "Admins gerenciam todos pedidos"
ON public.orders
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos itens de pedido" ON public.order_items;
CREATE POLICY "Admins gerenciam todos itens de pedido"
ON public.order_items
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Pedidos dos vendedores
ALTER TABLE public.seller_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos seller_orders" ON public.seller_orders;
CREATE POLICY "Admins gerenciam todos seller_orders"
ON public.seller_orders
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Carrinho
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos cart_items" ON public.cart_items;
CREATE POLICY "Admins gerenciam todos cart_items"
ON public.cart_items
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Notificações
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas notificacoes" ON public.notifications;
CREATE POLICY "Admins gerenciam todas notificacoes"
ON public.notifications
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Números de pagamento
ALTER TABLE public.payment_numbers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos payment_numbers" ON public.payment_numbers;
CREATE POLICY "Admins gerenciam todos payment_numbers"
ON public.payment_numbers
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Saldos / transações dos vendedores
ALTER TABLE public.seller_balances ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos seller_balances" ON public.seller_balances;
CREATE POLICY "Admins gerenciam todos seller_balances"
ON public.seller_balances
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

ALTER TABLE public.seller_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas seller_transactions" ON public.seller_transactions;
CREATE POLICY "Admins gerenciam todas seller_transactions"
ON public.seller_transactions
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Categorias / subcategorias
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas categories" ON public.categories;
CREATE POLICY "Admins gerenciam todas categories"
ON public.categories
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas subcategories" ON public.subcategories;
CREATE POLICY "Admins gerenciam todas subcategories"
ON public.subcategories
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

ALTER TABLE public.category_subcategories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas category_subcategories" ON public.category_subcategories;
CREATE POLICY "Admins gerenciam todas category_subcategories"
ON public.category_subcategories
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Chats / mensagens / toques
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos chats" ON public.chats;
CREATE POLICY "Admins gerenciam todos chats"
ON public.chats
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas chat_messages" ON public.chat_messages;
CREATE POLICY "Admins gerenciam todas chat_messages"
ON public.chat_messages
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

ALTER TABLE public.publication_touches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todas publication_touches" ON public.publication_touches;
CREATE POLICY "Admins gerenciam todas publication_touches"
ON public.publication_touches
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- Logs de pesquisa
ALTER TABLE public.search_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins gerenciam todos search_logs" ON public.search_logs;
CREATE POLICY "Admins gerenciam todos search_logs"
ON public.search_logs
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid())
);

-- ============================================
-- 3) CRIAR O PRIMEIRO ADMIN
-- ============================================
-- TROQUE o email abaixo pelo SEU email de admin
-- e rode APENAS UMA VEZ no SQL Editor:
--
-- INSERT INTO public.admin_users(user_id)
-- SELECT id FROM auth.users WHERE email = 'seu-email@dominio.com';
--
-- Depois disso, faça login com esse email no painel admin HTML.
-- ============================================
