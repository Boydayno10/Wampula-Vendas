-- ============================================
-- SETUP COMPLETO SUPABASE - WAMPULA VENDAS
-- ============================================
-- Execute TUDO de uma vez no SQL Editor do Supabase
-- ============================================

-- ============================================
-- PARTE 1: TABELA PROFILES
-- ============================================

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

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuários podem ver seu próprio perfil" ON public.profiles;
DROP POLICY IF EXISTS "Todos podem ver perfis públicos de vendedores" ON public.profiles;
DROP POLICY IF EXISTS "Usuários podem atualizar seu próprio perfil" ON public.profiles;
DROP POLICY IF EXISTS "Sistema pode criar perfis" ON public.profiles;

CREATE POLICY "Usuários podem ver seu próprio perfil"
ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Todos podem ver perfis públicos de vendedores"
ON public.profiles FOR SELECT USING (is_seller = true);

CREATE POLICY "Usuários podem atualizar seu próprio perfil"
ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "Sistema pode criar perfis"
ON public.profiles FOR INSERT WITH CHECK (true);

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
FOR EACH ROW EXECUTE FUNCTION public.handle_profiles_updated_at();

CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_is_seller_idx ON public.profiles(is_seller);
CREATE INDEX IF NOT EXISTS profiles_phone_idx ON public.profiles(phone);

-- ============================================
-- PARTE 2: STORAGE BUCKETS E POLÍTICAS
-- ============================================

-- Criar bucket para imagens de produtos
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Criar bucket para fotos de perfil
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-images', 'profile-images', true)
ON CONFLICT (id) DO NOTHING;

-- Criar bucket para banners de loja
INSERT INTO storage.buckets (id, name, public)
VALUES ('store-banners', 'store-banners', true)
ON CONFLICT (id) DO NOTHING;

-- POLÍTICAS PARA product-images
DROP POLICY IF EXISTS "Todos podem ver imagens de produtos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem fazer upload de imagens de produtos" ON storage.objects;
DROP POLICY IF EXISTS "Vendedores podem atualizar suas imagens de produtos" ON storage.objects;
DROP POLICY IF EXISTS "Vendedores podem deletar suas imagens de produtos" ON storage.objects;

CREATE POLICY "Todos podem ver imagens de produtos"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

CREATE POLICY "Usuários podem fazer upload de imagens de produtos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'product-images' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Vendedores podem atualizar suas imagens de produtos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'product-images' AND auth.role() = 'authenticated');

CREATE POLICY "Vendedores podem deletar suas imagens de produtos"
ON storage.objects FOR DELETE
USING (bucket_id = 'product-images' AND auth.role() = 'authenticated');

-- POLÍTICAS PARA profile-images
DROP POLICY IF EXISTS "Todos podem ver fotos de perfil" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem fazer upload de foto de perfil" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem atualizar sua foto de perfil" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem deletar sua foto de perfil" ON storage.objects;

CREATE POLICY "Todos podem ver fotos de perfil"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-images');

CREATE POLICY "Usuários podem fazer upload de foto de perfil"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'profile-images'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Usuários podem atualizar sua foto de perfil"
ON storage.objects FOR UPDATE
USING (bucket_id = 'profile-images' AND auth.role() = 'authenticated');

CREATE POLICY "Usuários podem deletar sua foto de perfil"
ON storage.objects FOR DELETE
USING (bucket_id = 'profile-images' AND auth.role() = 'authenticated');

-- POLÍTICAS PARA store-banners
DROP POLICY IF EXISTS "Todos podem ver banners de lojas" ON storage.objects;
DROP POLICY IF EXISTS "Vendedores podem fazer upload de banner" ON storage.objects;
DROP POLICY IF EXISTS "Vendedores podem atualizar seu banner" ON storage.objects;
DROP POLICY IF EXISTS "Vendedores podem deletar seu banner" ON storage.objects;

CREATE POLICY "Todos podem ver banners de lojas"
ON storage.objects FOR SELECT
USING (bucket_id = 'store-banners');

CREATE POLICY "Vendedores podem fazer upload de banner"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'store-banners'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Vendedores podem atualizar seu banner"
ON storage.objects FOR UPDATE
USING (bucket_id = 'store-banners' AND auth.role() = 'authenticated');

CREATE POLICY "Vendedores podem deletar seu banner"
ON storage.objects FOR DELETE
USING (bucket_id = 'store-banners' AND auth.role() = 'authenticated');

-- ============================================
-- ✅ SETUP COMPLETO!
-- ============================================
-- Agora o app vai funcionar com:
-- ✅ Upload de fotos de perfil
-- ✅ Upload de banners de loja  
-- ✅ Upload de imagens de produtos
-- ✅ Perfis persistentes no banco
-- ============================================
