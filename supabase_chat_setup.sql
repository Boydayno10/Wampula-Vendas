-- ================================
-- Tabelas de Chat em tempo real para Publicações de Clientes
-- ================================

-- Tabela de toques em publicações de clientes
CREATE TABLE IF NOT EXISTS public.publication_touches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_id uuid NOT NULL REFERENCES public.client_publications(id) ON DELETE CASCADE,
  -- Usuário que deu o toque
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Dono da publicação (para facilitar filtros e Realtime)
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabela de conversas (chat)
-- Agora permite publication_id nulo para suportar chats diretos (ex: pedidos)
CREATE TABLE IF NOT EXISTS public.chats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_id uuid REFERENCES public.client_publications(id) ON DELETE CASCADE,
  user1_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user2_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Código de pedido associado ao chat (ex: "WP-00001") para
-- identificar conversas de suporte/reembolso ligadas a um pedido.
ALTER TABLE public.chats
  ADD COLUMN IF NOT EXISTS order_code text;

-- Tabela de mensagens de chat
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message text NOT NULL,
  image_url text,
  is_admin_message boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- ================================
-- Indexes úteis
-- ================================

CREATE INDEX IF NOT EXISTS idx_publication_touches_publication
  ON public.publication_touches (publication_id);

CREATE INDEX IF NOT EXISTS idx_publication_touches_owner
  ON public.publication_touches (owner_id);

CREATE INDEX IF NOT EXISTS idx_chats_publication
  ON public.chats (publication_id);

CREATE INDEX IF NOT EXISTS idx_chats_users
  ON public.chats (user1_id, user2_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_chat
  ON public.chat_messages (chat_id, created_at);

-- Resposta de mensagem (reply)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid
    REFERENCES public.chat_messages(id) ON DELETE SET NULL;

-- Flag para identificar mensagens enviadas a partir do painel Admin
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS is_admin_message boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_chat_messages_reply_to
  ON public.chat_messages(reply_to_message_id);

-- ================================
-- RLS (Row Level Security)
-- ================================

ALTER TABLE public.publication_touches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Policies para publication_touches

CREATE POLICY publication_touches_insert
ON public.publication_touches
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY publication_touches_select
ON public.publication_touches
FOR SELECT
USING (
  -- Quem deu o toque vê o próprio registro
  auth.uid() = user_id
  OR
  -- Dono da publicação vê toques recebidos
  auth.uid() = owner_id
);

-- Policies para chats

CREATE POLICY chats_insert
ON public.chats
FOR INSERT
WITH CHECK (
  auth.uid() = user1_id OR auth.uid() = user2_id
);

CREATE POLICY chats_select
ON public.chats
FOR SELECT
USING (
  auth.uid() = user1_id OR auth.uid() = user2_id
);

-- Policies para chat_messages

CREATE POLICY chat_messages_insert
ON public.chat_messages
FOR INSERT
WITH CHECK (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.chats c
    WHERE c.id = chat_id
      AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
  )
);

CREATE POLICY chat_messages_select
ON public.chat_messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.chats c
    WHERE c.id = chat_id
      AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
  )
);

-- Permitir que o remetente atualize o próprio texto da mensagem
CREATE POLICY chat_messages_update
ON public.chat_messages
FOR UPDATE
USING (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.chats c
    WHERE c.id = chat_id
      AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
  )
)
WITH CHECK (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.chats c
    WHERE c.id = chat_id
      AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
  )
);

-- Permitir que o remetente apague a própria mensagem para os dois
CREATE POLICY chat_messages_delete
ON public.chat_messages
FOR DELETE
USING (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.chats c
    WHERE c.id = chat_id
      AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
  )
);

-- ================================
-- Campo de "mensagem lida" e função para marcar como lida
-- ================================

-- Marca quando o destinatário visualizou a mensagem
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS read_at timestamp with time zone;

-- Função segura para marcar todas as mensagens recebidas de um chat como lidas
-- Observação: executada como SECURITY DEFINER para contornar RLS, mas
-- sempre validando se auth.uid() é participante do chat.
CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(p_chat_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Garante que o usuário é participante do chat
  IF NOT EXISTS (
    SELECT 1
    FROM public.chats c
    WHERE c.id = p_chat_id
      AND (c.user1_id = v_user_id OR c.user2_id = v_user_id)
  ) THEN
    RAISE EXCEPTION 'Usuário não autorizado para este chat';
  END IF;

  -- Marca como lidas todas as mensagens recebidas (do outro usuário)
  UPDATE public.chat_messages m
  SET read_at = now()
  WHERE m.chat_id = p_chat_id
    AND m.sender_id <> v_user_id
    AND m.read_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_chat_messages_as_read(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_chat_messages_as_read(uuid) TO anon, authenticated;
