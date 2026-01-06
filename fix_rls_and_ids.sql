-- ====================================
-- FIX RLS E IMPLEMENTAR IDs SEQUENCIAIS
-- ====================================

-- 1. CRIAR SEQUÊNCIA PARA IDs DE PEDIDOS
CREATE SEQUENCE IF NOT EXISTS order_id_seq START WITH 1;

-- 2. CRIAR FUNÇÃO PARA GERAR IDs SEQUENCIAIS
CREATE OR REPLACE FUNCTION generate_order_id()
RETURNS TEXT AS $$
DECLARE
  next_id INTEGER;
  formatted_id TEXT;
BEGIN
  next_id := nextval('order_id_seq');
  formatted_id := 'WP-' || LPAD(next_id::TEXT, 5, '0');
  RETURN formatted_id;
END;
$$ LANGUAGE plpgsql;

-- 3. CORRIGIR POLÍTICAS RLS DE seller_balances
-- Remover TODAS as políticas antigas (todas as variações de nome)
DROP POLICY IF EXISTS "Vendedores podem ver seu próprio saldo" ON seller_balances;
DROP POLICY IF EXISTS "Vendedores podem atualizar seu próprio saldo" ON seller_balances;
DROP POLICY IF EXISTS "Sistema pode inserir saldos" ON seller_balances;
DROP POLICY IF EXISTS "Vendedores podem ver seu saldo" ON seller_balances;
DROP POLICY IF EXISTS "Vendedores podem atualizar seu saldo" ON seller_balances;

-- Criar políticas corretas
CREATE POLICY "Vendedores podem ver seu saldo"
  ON seller_balances FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Vendedores podem atualizar seu saldo"
  ON seller_balances FOR UPDATE
  USING (auth.uid() = seller_id)
  WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sistema pode inserir saldos"
  ON seller_balances FOR INSERT
  WITH CHECK (true);  -- Permitir inserção de triggers

-- 4. CRIAR/ATUALIZAR TRIGGER PARA ATUALIZAR SALDOS
CREATE OR REPLACE FUNCTION update_seller_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- Quando pedido é marcado como entregue, atualizar saldo
  IF NEW.status = 'entregue' AND (OLD.status IS NULL OR OLD.status <> 'entregue') THEN
    -- Inserir ou atualizar saldo do vendedor
    INSERT INTO seller_balances (seller_id, available_balance, pending_balance, total_earnings)
    VALUES (
      NEW.seller_id,
      NEW.total * 0.9,  -- 90% do valor (10% de comissão)
      0,
      NEW.total
    )
    ON CONFLICT (seller_id) DO UPDATE SET
      available_balance = seller_balances.available_balance + NEW.total * 0.9,
      total_earnings = seller_balances.total_earnings + NEW.total,
      updated_at = now();
    
    -- Criar transação
    INSERT INTO seller_transactions (seller_id, type, amount, description, order_id)
    VALUES (
      NEW.seller_id,
      'venda',
      NEW.total,
      'Venda do pedido #' || NEW.id,
      NEW.id
    );
    
    -- Criar transação de comissão
    INSERT INTO seller_transactions (seller_id, type, amount, description, order_id)
    VALUES (
      NEW.seller_id,
      'comissao',
      NEW.total * 0.1,
      'Comissão (10%) do pedido #' || NEW.id,
      NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;  -- SECURITY DEFINER permite bypass do RLS

-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS on_seller_order_delivered ON seller_orders;

-- Criar novo trigger
CREATE TRIGGER on_seller_order_delivered
  AFTER UPDATE ON seller_orders
  FOR EACH ROW
  WHEN (NEW.status = 'entregue')
  EXECUTE FUNCTION update_seller_balance();

-- 5. GARANTIR QUE TABELA seller_balances EXISTE E TEM RLS ATIVO
ALTER TABLE seller_balances ENABLE ROW LEVEL SECURITY;

-- 6. CRIAR POLÍTICA PARA TRANSAÇÕES
DROP POLICY IF EXISTS "Vendedores podem ver suas transações" ON seller_transactions;
DROP POLICY IF EXISTS "Sistema pode criar transações" ON seller_transactions;

CREATE POLICY "Vendedores podem ver suas transações"
  ON seller_transactions FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Sistema pode criar transações"
  ON seller_transactions FOR INSERT
  WITH CHECK (true);  -- Permitir inserção de triggers

ALTER TABLE seller_transactions ENABLE ROW LEVEL SECURITY;

-- 7. CORRIGIR ENUM seller_order_status PARA INCLUIR 'enviado' E 'reembolsoSolicitado'
-- Verificar se enum existe e tem os valores corretos
DO $$
BEGIN
  -- Adicionar 'enviado' se não existir
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'enviado' 
    AND enumtypid = 'seller_order_status'::regtype
  ) THEN
    ALTER TYPE seller_order_status ADD VALUE 'enviado' AFTER 'processando';
  END IF;
  
  -- Adicionar 'reembolsoSolicitado' se não existir
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'reembolsoSolicitado' 
    AND enumtypid = 'seller_order_status'::regtype
  ) THEN
    ALTER TYPE seller_order_status ADD VALUE 'reembolsoSolicitado';
  END IF;
END$$;

-- 7.1 CORRIGIR ENUM order_status (TABELA DO CLIENTE) PARA INCLUIR 'reembolsoSolicitado'
DO $$
BEGIN
  -- Adicionar 'reembolsoSolicitado' se não existir
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'reembolsoSolicitado' 
    AND enumtypid = 'order_status'::regtype
  ) THEN
    ALTER TYPE order_status ADD VALUE 'reembolsoSolicitado';
  END IF;
END$$;

-- 7.2 CORRIGIR ENUM transaction_type PARA INCLUIR 'reembolso'
DO $$
BEGIN
  -- Adicionar 'reembolso' se não existir
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'reembolso' 
    AND enumtypid = 'transaction_type'::regtype
  ) THEN
    ALTER TYPE transaction_type ADD VALUE 'reembolso';
  END IF;
END$$;

-- 8. CRIAR FUNÇÃO RPC PARA GERAR PRÓXIMO ID SEQUENCIAL COM REUTILIZAÇÃO DE NÚMEROS
CREATE OR REPLACE FUNCTION get_next_order_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_id INTEGER;
  existing_ids INTEGER[];
  i INTEGER;
BEGIN
  -- Buscar todos os IDs numéricos existentes de ambas as tabelas
  SELECT ARRAY_AGG(DISTINCT num ORDER BY num)
  INTO existing_ids
  FROM (
    SELECT CAST(SUBSTRING(id FROM 4) AS INTEGER) AS num
    FROM orders
    WHERE id ~ '^WP-[0-9]+$'
    UNION
    SELECT CAST(SUBSTRING(id FROM 4) AS INTEGER) AS num
    FROM seller_orders
    WHERE id ~ '^WP-[0-9]+$'
  ) AS all_ids;
  
  -- Se não houver pedidos, começar do 1
  IF existing_ids IS NULL OR array_length(existing_ids, 1) IS NULL THEN
    RETURN 'WP-00001';
  END IF;
  
  -- Procurar o primeiro número disponível (buraco na sequência)
  FOR i IN 1..existing_ids[array_length(existing_ids, 1)] LOOP
    IF NOT (i = ANY(existing_ids)) THEN
      -- Encontrou um buraco, usar esse número
      RETURN 'WP-' || LPAD(i::TEXT, 5, '0');
    END IF;
  END LOOP;
  
  -- Se não houver buracos, usar o próximo número após o maior
  next_id := existing_ids[array_length(existing_ids, 1)] + 1;
  
  RETURN 'WP-' || LPAD(next_id::TEXT, 5, '0');
END;
$$;

-- 9. CRIAR FUNÇÃO RPC PARA DELETAR PEDIDO COMPLETAMENTE
CREATE OR REPLACE FUNCTION delete_order_complete(order_id_param TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Deletar order_items primeiro (foreign key)
  DELETE FROM order_items WHERE order_id = order_id_param;
  
  -- Deletar seller_orders
  DELETE FROM seller_orders WHERE id = order_id_param;
  
  -- Deletar orders (cliente)
  DELETE FROM orders WHERE id = order_id_param;
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 10. CRIAR FUNÇÃO RPC PARA ATUALIZAR SALDO NO REEMBOLSO
CREATE OR REPLACE FUNCTION update_seller_balance_refund(p_seller_id UUID, p_amount NUMERIC)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Deduzir valor do saldo disponível do vendedor
  UPDATE seller_balances
  SET 
    available_balance = available_balance - p_amount,
    updated_at = now()
  WHERE seller_id = p_seller_id;
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

COMMIT;
