-- =====================================================
-- TABELA DE NÚMEROS DE PAGAMENTO (M-PESA)
-- =====================================================

-- Criar tabela payment_numbers
CREATE TABLE IF NOT EXISTS payment_numbers (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  number TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_payment_numbers_user_id ON payment_numbers(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_numbers_is_primary ON payment_numbers(user_id, is_primary);

-- RLS (Row Level Security)
ALTER TABLE payment_numbers ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança
-- Usuários podem ver apenas seus próprios números
CREATE POLICY "Usuários podem ver seus números de pagamento"
  ON payment_numbers
  FOR SELECT
  USING (auth.uid() = user_id);

-- Usuários podem inserir seus próprios números
CREATE POLICY "Usuários podem adicionar números de pagamento"
  ON payment_numbers
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Usuários podem atualizar apenas seus próprios números
CREATE POLICY "Usuários podem atualizar seus números de pagamento"
  ON payment_numbers
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Usuários podem deletar apenas seus próprios números
CREATE POLICY "Usuários podem deletar seus números de pagamento"
  ON payment_numbers
  FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_payment_numbers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_payment_numbers_updated_at
  BEFORE UPDATE ON payment_numbers
  FOR EACH ROW
  EXECUTE FUNCTION update_payment_numbers_updated_at();

-- Garantir que apenas um número seja principal por usuário
CREATE OR REPLACE FUNCTION ensure_single_primary_payment()
RETURNS TRIGGER AS $$
BEGIN
  -- Se o novo número está sendo marcado como principal
  IF NEW.is_primary = TRUE THEN
    -- Desmarcar todos os outros números deste usuário como principal
    UPDATE payment_numbers
    SET is_primary = FALSE
    WHERE user_id = NEW.user_id
      AND id != NEW.id
      AND is_primary = TRUE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ensure_single_primary_payment
  BEFORE INSERT OR UPDATE ON payment_numbers
  FOR EACH ROW
  WHEN (NEW.is_primary = TRUE)
  EXECUTE FUNCTION ensure_single_primary_payment();

-- Comentários para documentação
COMMENT ON TABLE payment_numbers IS 'Números de pagamento M-Pesa dos usuários';
COMMENT ON COLUMN payment_numbers.user_id IS 'ID do usuário proprietário do número';
COMMENT ON COLUMN payment_numbers.number IS 'Número de telefone M-Pesa';
COMMENT ON COLUMN payment_numbers.is_primary IS 'Se este é o número principal do usuário';
