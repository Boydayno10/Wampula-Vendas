-- ============================================
-- ADICIONAR COLUNAS FALTANTES NA TABELA PROFILES
-- ============================================
-- Execute isso no SQL Editor do Supabase AGORA
-- ============================================

-- Adicionar colunas faltantes se não existirem
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS store_name TEXT,
ADD COLUMN IF NOT EXISTS store_description TEXT DEFAULT 'Bem-vindo à nossa loja!',
ADD COLUMN IF NOT EXISTS store_banner TEXT;

-- ============================================
-- ✅ PRONTO! Agora hot reload o app
-- ============================================
