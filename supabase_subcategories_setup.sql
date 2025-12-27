-- ==========================================
-- 📋 TABELA DE SUBCATEGORIAS DINÂMICAS
-- ==========================================
-- Gerenciadas apenas por administradores no Supabase
-- Vendedores e clientes apenas visualizam

CREATE TABLE IF NOT EXISTS public.subcategories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  filter_type text NOT NULL, -- 'maisPopulares', 'maisComprados', 'maisBaratos', 'novos', 'promocoes', 'recomendados'
  display_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT subcategories_pkey PRIMARY KEY (id),
  CONSTRAINT subcategories_filter_type_check CHECK (
    filter_type IN ('maisPopulares', 'maisComprados', 'maisBaratos', 'novos', 'promocoes', 'recomendados')
  )
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_subcategories_active ON public.subcategories(active);
CREATE INDEX IF NOT EXISTS idx_subcategories_display_order ON public.subcategories(display_order);
CREATE INDEX IF NOT EXISTS idx_subcategories_filter_type ON public.subcategories(filter_type);

-- ==========================================
-- 🔐 ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Qualquer pessoa pode ver subcategorias ativas" ON public.subcategories;
DROP POLICY IF EXISTS "Apenas admins podem gerenciar subcategorias" ON public.subcategories;

-- Política: Todos podem ler subcategorias ativas
CREATE POLICY "Qualquer pessoa pode ver subcategorias ativas"
  ON public.subcategories
  FOR SELECT
  USING (active = true);

-- Política: Apenas administradores podem inserir/atualizar/deletar
-- (Configure service_role ou adicione lógica de admin conforme seu sistema)
CREATE POLICY "Apenas admins podem gerenciar subcategorias"
  ON public.subcategories
  FOR ALL
  USING (
    -- Substitua esta condição pela sua lógica de admin
    -- Por exemplo: auth.jwt()->>'role' = 'admin'
    false -- Por padrão bloqueado, gerencie via Dashboard do Supabase
  );

-- ==========================================
-- 📊 DADOS INICIAIS (SUBCATEGORIAS PADRÃO)
-- ==========================================
INSERT INTO public.subcategories (name, description, filter_type, display_order, active) VALUES
  ('Mais populares', 'Produtos com mais cliques e visualizações', 'maisPopulares', 1, true),
  ('Mais comprados', 'Produtos com mais vendas', 'maisComprados', 2, true),
  ('Mais baratos', 'Melhores preços', 'maisBaratos', 3, true),
  ('Novos', 'Produtos adicionados recentemente', 'novos', 4, true),
  ('Promoções', 'Produtos com desconto', 'promocoes', 5, true),
  ('Recomendados', 'Produtos recomendados para você', 'recomendados', 6, true)
ON CONFLICT (name) DO NOTHING;

-- ==========================================
-- 🔄 TRIGGER PARA UPDATED_AT
-- ==========================================
-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS trigger_update_subcategories_updated_at ON public.subcategories;

-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS trigger_update_subcategories_updated_at ON public.subcategories;

CREATE OR REPLACE FUNCTION update_subcategories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_subcategories_updated_at
  BEFORE UPDATE ON public.subcategories
  FOR EACH ROW
  EXECUTE FUNCTION update_subcategories_updated_at();

-- ==========================================
-- ✅ VERIFICAÇÃO
-- ==========================================
-- Execute para verificar as subcategorias criadas:
-- SELECT * FROM public.subcategories ORDER BY display_order;
