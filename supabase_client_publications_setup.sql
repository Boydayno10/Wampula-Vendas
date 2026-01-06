-- ================================
-- Tabela de Publicações de Clientes
-- ================================

CREATE TABLE IF NOT EXISTS public.client_publications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price numeric NOT NULL CHECK (price >= 0),
  promo_price numeric CHECK (promo_price >= 0),
  images jsonb NOT NULL DEFAULT '[]'::jsonb,
  category text NOT NULL DEFAULT 'Casa',
  active boolean NOT NULL DEFAULT true,
  has_location_enabled boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '24 hours')
);

-- ================================
-- RLS - Qualquer usuário pode LER publicações ativas,
-- mas somente o dono pode criar/editar/apagar
-- ================================

ALTER TABLE public.client_publications ENABLE ROW LEVEL SECURITY;

-- Atenção: rode estes CREATE POLICY apenas uma vez.
-- Se já existirem policies com esses nomes, apague-as manualmente
-- ou ajuste os nomes abaixo antes de executar.

-- Agora qualquer usuário (inclusive anônimo) pode ver publicações
-- de clientes. O filtro de 24h continua sendo feito pela coluna
-- expires_at e pela função de limpeza.
CREATE POLICY client_publications_select
ON public.client_publications
FOR SELECT
USING (true);

CREATE POLICY client_publications_insert
ON public.client_publications
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY client_publications_update
ON public.client_publications
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY client_publications_delete
ON public.client_publications
FOR DELETE
USING (auth.uid() = user_id);

-- ================================
-- Função para apagar publicações expiradas (24h)
-- ================================

CREATE OR REPLACE FUNCTION public.delete_expired_client_publications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.client_publications
  WHERE expires_at <= now();
END;
$$;

-- Você pode agendar esta função no Supabase (Scheduled Functions)
-- para rodar a cada hora, mas o app já chama a função
-- antes de listar as publicações do cliente.
