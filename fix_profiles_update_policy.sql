-- =====================================================
-- CORRIGIR POLÍTICA DE UPDATE DE PERFIS
-- =====================================================

-- Primeiro, vamos remover a política antiga
DROP POLICY IF EXISTS "Usuários podem atualizar seu próprio perfil" ON public.profiles;

-- Criar a política correta para UPDATE
CREATE POLICY "Usuários podem atualizar seu próprio perfil"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Verificar se a política foi criada corretamente
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'profiles' 
  AND policyname = 'Usuários podem atualizar seu próprio perfil';

-- Teste: tentar atualizar o próprio perfil
-- Substitua 'SEU_USER_ID' pelo ID do seu usuário de teste
-- UPDATE public.profiles 
-- SET bairro = 'Muhala' 
-- WHERE id = auth.uid();
