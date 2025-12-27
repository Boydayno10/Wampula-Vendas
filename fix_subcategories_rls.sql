-- ================================================================
-- 🔧 CORRIGIR POLÍTICAS RLS DAS SUBCATEGORIAS
-- ================================================================
-- Problema: RLS está bloqueando leitura das subcategorias
-- Solução: Permitir leitura pública (sem autenticação)
-- ================================================================

-- ==========================================
-- 1️⃣ REMOVER POLÍTICAS ANTIGAS
-- ==========================================
DROP POLICY IF EXISTS "Qualquer pessoa pode ver subcategorias ativas" ON public.subcategories;
DROP POLICY IF EXISTS "Apenas admins podem gerenciar subcategorias" ON public.subcategories;

-- ==========================================
-- 2️⃣ CRIAR POLÍTICAS CORRETAS
-- ==========================================

-- ✅ Política de LEITURA PÚBLICA (sem autenticação necessária)
CREATE POLICY "public_read_subcategories"
  ON public.subcategories
  FOR SELECT
  USING (true); -- Permite leitura para TODOS (autenticados ou não)

-- 🔒 Política de ESCRITA apenas para admins (via service_role)
CREATE POLICY "admin_manage_subcategories"
  ON public.subcategories
  FOR ALL
  USING (false) -- Bloqueia tudo por padrão
  WITH CHECK (false); -- Gerenciar apenas via Dashboard ou service_role

-- ==========================================
-- 3️⃣ VERIFICAR SE RLS ESTÁ HABILITADO
-- ==========================================
ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 4️⃣ TESTAR SUBCATEGORIAS
-- ==========================================
-- Esta query deve retornar as 6 subcategorias
SELECT 
  name, 
  filter_type, 
  display_order, 
  active 
FROM public.subcategories 
WHERE active = true
ORDER BY display_order;

-- ==========================================
-- ✅ RESULTADO ESPERADO
-- ==========================================
-- Deve mostrar 6 linhas:
-- 1. Mais populares - maisPopulares - 1 - true
-- 2. Mais comprados - maisComprados - 2 - true
-- 3. Mais baratos - maisBaratos - 3 - true
-- 4. Novos - novos - 4 - true
-- 5. Promoções - promocoes - 5 - true
-- 6. Recomendados - recomendados - 6 - true
-- ==========================================

-- ==========================================
-- 📝 PRÓXIMOS PASSOS
-- ==========================================
-- 1. Execute este script no SQL Editor do Supabase
-- 2. Verifique se as 6 subcategorias aparecem na query acima
-- 3. Reinicie o app Flutter (hot restart)
-- 4. As subcategorias devem aparecer agora!
-- ==========================================
