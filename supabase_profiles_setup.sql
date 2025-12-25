-- ============================================
-- TABELA DE PERFIS DE USUÁRIOS
-- ============================================
-- Execute no SQL Editor do Supabase
-- Cria tabela para armazenar dados adicionais dos usuários
-- ============================================

-- Criar tabela de perfis
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    bairro TEXT NOT NULL,
    is_seller BOOLEAN DEFAULT true,
    verified BOOLEAN DEFAULT true,
    profile_image_url TEXT,
    store_name TEXT,
    store_description TEXT DEFAULT 'Bem-vindo à nossa loja!',
    store_banner TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes
DROP POLICY IF EXISTS "Usuários podem ver seu próprio perfil" ON public.profiles;
DROP POLICY IF EXISTS "Usuários podem atualizar seu próprio perfil" ON public.profiles;
DROP POLICY IF EXISTS "Sistema pode criar perfis" ON public.profiles;
DROP POLICY IF EXISTS "Todos podem ver perfis públicos de vendedores" ON public.profiles;

-- Políticas RLS
CREATE POLICY "Usuários podem ver seu próprio perfil"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Todos podem ver perfis públicos de vendedores"
ON public.profiles FOR SELECT
USING (is_seller = true);

CREATE POLICY "Usuários podem atualizar seu próprio perfil"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Sistema pode criar perfis"
ON public.profiles FOR INSERT
WITH CHECK (true);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profiles_updated_at();

-- Índices para performance
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_is_seller_idx ON public.profiles(is_seller);
CREATE INDEX IF NOT EXISTS profiles_phone_idx ON public.profiles(phone);

-- ============================================
-- ✅ TABELA PROFILES CRIADA COM SUCESSO!
-- ============================================
-- Agora você pode:
-- 1. Criar contas de usuários
-- 2. Editar perfis e fotos
-- 3. Atualizar informações da loja
-- 4. Fazer upload de banners
-- ============================================
