# 🚨 INSTRUÇÕES URGENTES - EXECUTE NO SUPABASE SQL EDITOR

## ⚠️ IMPORTANTE: Execute este SQL ANTES de testar o app!

Vá para: **Supabase Dashboard → SQL Editor → New Query**

Copie e cole todo o conteúdo abaixo e clique em **RUN**:

```sql
-- ====================================
-- CORREÇÃO COMPLETA DO SISTEMA + REEMBOLSOS
-- ====================================

-- 1. CRIAR SEQUÊNCIA PARA IDs SEQUENCIAIS (WP-00001, WP-00002, ...)
CREATE SEQUENCE IF NOT EXISTS order_id_seq START WITH 1;

-- 2. FUNÇÃO PARA GERAR PRÓXIMO ID
CREATE OR REPLACE FUNCTION get_next_order_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  next_id INTEGER;
BEGIN
  next_id := nextval('order_id_seq');
  RETURN 'WP-' || LPAD(next_id::TEXT, 5, '0');
END;
$$;

-- 3. FUNÇÃO PARA DELETAR PEDIDO COMPLETAMENTE
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
    RAISE NOTICE 'Erro ao deletar pedido: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- 4. ADICIONAR 'enviado' AO ENUM seller_order_status
DO $$
BEGIN
  -- Verificar se 'enviado' já existe
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'enviado' 
    AND enumtypid = 'seller_order_status'::regtype
  ) THEN
    ALTER TYPE seller_order_status ADD VALUE 'enviado' AFTER 'processando';
    RAISE NOTICE '✅ Valor "enviado" adicionado ao enum seller_order_status';
  ELSE
    RAISE NOTICE '⚠️ Valor "enviado" já existe no enum';
  END IF;
END$$;

-- 5. CORRIGIR POLÍTICAS RLS DE seller_balances
DROP POLICY IF EXISTS "Vendedores podem ver seu próprio saldo" ON seller_balances;
DROP POLICY IF EXISTS "Vendedores podem atualizar seu próprio saldo" ON seller_balances;
DROP POLICY IF EXISTS "Sistema pode inserir saldos" ON seller_balances;
DROP POLICY IF EXISTS "Vendedores podem ver seu saldo" ON seller_balances;

CREATE POLICY "Vendedores podem ver seu saldo"
  ON seller_balances FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Vendedores podem atualizar seu saldo"
  ON seller_balances FOR UPDATE
  USING (auth.uid() = seller_id)
  WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sistema pode inserir saldos"
  ON seller_balances FOR INSERT
  WITH CHECK (true);

ALTER TABLE seller_balances ENABLE ROW LEVEL SECURITY;

-- 6. CRIAR TRIGGER PARA ATUALIZAR SALDOS (COM SECURITY DEFINER)
CREATE OR REPLACE FUNCTION update_seller_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'entregue' AND (OLD.status IS NULL OR OLD.status <> 'entregue') THEN
    -- Inserir ou atualizar saldo
    INSERT INTO seller_balances (seller_id, available_balance, pending_balance, total_earnings)
    VALUES (
      NEW.seller_id,
      NEW.total * 0.9,
      0,
      NEW.total
    )
    ON CONFLICT (seller_id) DO UPDATE SET
      available_balance = seller_balances.available_balance + NEW.total * 0.9,
      total_earnings = seller_balances.total_earnings + NEW.total,
      updated_at = now();
    
    -- Criar transação de venda
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_seller_order_delivered ON seller_orders;

CREATE TRIGGER on_seller_order_delivered
  AFTER UPDATE ON seller_orders
  FOR EACH ROW
  WHEN (NEW.status = 'entregue')
  EXECUTE FUNCTION update_seller_balance();

-- 7. ADICIONAR 'reembolsoSolicitado' AO ENUM seller_order_status
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'reembolsoSolicitado' 
    AND enumtypid = 'seller_order_status'::regtype
  ) THEN
    ALTER TYPE seller_order_status ADD VALUE 'reembolsoSolicitado';
    RAISE NOTICE '✅ Valor "reembolsoSolicitado" adicionado ao enum seller_order_status';
  ELSE
    RAISE NOTICE '⚠️ Valor "reembolsoSolicitado" já existe no enum';
  END IF;
END$$;

-- 8. CRIAR FUNÇÃO PARA ATUALIZAR SALDO NO REEMBOLSO
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

-- 9. CORRIGIR POLÍTICAS DE seller_transactions
DROP POLICY IF EXISTS "Vendedores podem ver suas transações" ON seller_transactions;
DROP POLICY IF EXISTS "Sistema pode criar transações" ON seller_transactions;

CREATE POLICY "Vendedores podem ver suas transações"
  ON seller_transactions FOR SELECT
  USING (auth.uid() = seller_id);

CREATE POLICY "Sistema pode criar transações"
  ON seller_transactions FOR INSERT
  WITH CHECK (true);

ALTER TABLE seller_transactions ENABLE ROW LEVEL SECURITY;

-- 10. VERIFICAR ENUMS
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = 'seller_order_status'::regtype 
ORDER BY enumsortorder;

-- 11. TESTAR FUNÇÕES
SELECT get_next_order_id();
SELECT get_next_order_id();
SELECT get_next_order_id();

-- ✅ CONCLUÍDO!
```

## 📋 Verificação

Após executar, você deve ver:

1. ✅ Mensagem: "Valor 'enviado' adicionado ao enum seller_order_status"
2. ✅ Mensagem: "Valor 'reembolsoSolicitado' adicionado ao enum seller_order_status"
3. ✅ Lista de valores do enum: novo, processando, enviado, entregue, cancelado, reembolsoSolicitado
4. ✅ Três IDs gerados: WP-00001, WP-00002, WP-00003

## 🎯 Próximos Passos

1. Execute o SQL acima no Supabase
2. Reinicie o app Flutter
3. **Teste Sistema de Reembolso:**
   - Como cliente: Solicite reembolso de um pedido
   - Como vendedor: Veja pedido com status "Reembolso Solicitado"
   - Como vendedor: Aprove ou negue o reembolso
   - Verifique que saldo é atualizado corretamente
4. Teste criar novo pedido → Deve ter ID WP-00001
5. Teste deletar pedido → Deve remover completamente

## ❓ Se ainda não funcionar

Envie screenshot do resultado da execução do SQL no Supabase.
