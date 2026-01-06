-- ==========================================
-- TABELA DE SUBCATEGORIAS POR CATEGORIA
-- ==========================================
-- Esta tabela liga uma categoria principal a subcategorias "reais"
-- escolhidas pelo vendedor no cadastro de produto.
-- NÃO substitui o sistema global de subcategorias (tabela public.subcategories)
-- usado na Home (Mais populares, Mais comprados, etc.).

CREATE TABLE IF NOT EXISTS public.category_subcategories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_name text NOT NULL,
  name text NOT NULL,
  description text,
  display_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_category_subcategories_category_name
  ON public.category_subcategories(category_name);

CREATE INDEX IF NOT EXISTS idx_category_subcategories_active
  ON public.category_subcategories(active);

CREATE INDEX IF NOT EXISTS idx_category_subcategories_display_order
  ON public.category_subcategories(display_order);

-- RLS
ALTER TABLE public.category_subcategories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Qualquer pessoa pode ver category_subcategories ativas"
  ON public.category_subcategories;

CREATE POLICY "Qualquer pessoa pode ver category_subcategories ativas"
  ON public.category_subcategories
  FOR SELECT
  USING (active = true);

-- Admins (service role) podem gerenciar
DROP POLICY IF EXISTS "Apenas admins podem gerenciar category_subcategories"
  ON public.category_subcategories;

CREATE POLICY "Apenas admins podem gerenciar category_subcategories"
  ON public.category_subcategories
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Trigger updated_at
DROP TRIGGER IF EXISTS trigger_update_category_subcategories_updated_at
  ON public.category_subcategories;

CREATE OR REPLACE FUNCTION update_category_subcategories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_category_subcategories_updated_at
  BEFORE UPDATE ON public.category_subcategories
  FOR EACH ROW
  EXECUTE FUNCTION update_category_subcategories_updated_at();

-- Exemplo de inserção (AJUSTE no Supabase conforme seu catálogo):
-- INSERT INTO public.category_subcategories (category_name, name, description, display_order, active)
-- VALUES
--   ('Vestuário', 'T-Shirts', 'Camisetas em geral', 1, true),
--   ('Vestuário', 'Calças', 'Calças masculinas e femininas', 2, true),
--   ('Eletrónicos', 'Smartphones', 'Telemóveis e smartphones', 1, true),
--   ('Eletrónicos', 'Tablets', 'Tablets e iPads', 2, true);
