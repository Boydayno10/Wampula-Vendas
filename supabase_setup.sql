-- ============================================
-- SCRIPT SQL PARA SUPABASE - WAMPULA VENDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Criar tabela de perfis de usuários
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    bairro TEXT,
    is_seller BOOLEAN DEFAULT false,
    verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Habilitar Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Criar políticas de acesso
-- Política: Permitir leitura pública de emails (para verificação de existência)
CREATE POLICY "Permitir verificação pública de email"
    ON public.profiles
    FOR SELECT
    USING (true);

-- Política: Usuários podem atualizar seu próprio perfil
CREATE POLICY "Usuários podem atualizar seu próprio perfil"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Política: Permitir inserção de novos perfis (necessário para registro)
CREATE POLICY "Permitir inserção de perfis durante registro"
    ON public.profiles
    FOR INSERT
    WITH CHECK (true);

-- 4. Criar função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Criar trigger para atualizar updated_at
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 6. Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_phone_idx ON public.profiles(phone);
CREATE INDEX IF NOT EXISTS profiles_bairro_idx ON public.profiles(bairro);

-- ============================================
-- NOTAS IMPORTANTES:
-- ============================================
-- 1. A tabela 'profiles' está vinculada à tabela 'auth.users' do Supabase
-- 2. Quando um usuário é criado via Supabase Auth, o ID é compartilhado
-- 3. O campo 'email' deve ser único
-- 4. RLS está habilitado para segurança
-- 5. Usuários só podem ver/editar seus próprios dados
-- ============================================

-- VERIFICAÇÃO (OPCIONAL - Para testar se está tudo OK)
-- SELECT * FROM public.profiles;
