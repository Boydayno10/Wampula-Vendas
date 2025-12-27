-- ============================================
-- MIGRAÇÃO: Adicionar coluna images à tabela products
-- ============================================
-- Execute este script no SQL Editor do Supabase
-- Dashboard > SQL Editor > Nova Query > Cole e Execute
-- ============================================

-- 1. Tornar coluna 'image' nullable (remover constraint NOT NULL)
ALTER TABLE products 
ALTER COLUMN image DROP NOT NULL;

-- 2. Adicionar coluna images (JSONB array) à tabela products
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]';

-- 3. Migrar dados existentes da coluna image para images
-- Isto converterá cada string de imagem única em um array com um elemento
UPDATE products 
SET images = jsonb_build_array(image)
WHERE (images = '[]' OR images IS NULL) AND image IS NOT NULL;

-- 4. Para produtos sem imagem, definir array vazio
UPDATE products 
SET images = '[]'
WHERE images IS NULL;

-- Opcional: Remover coluna antiga 'image' após confirmar que a migração funcionou
-- ATENÇÃO: Só execute isto depois de testar que tudo está funcionando por alguns dias!
-- ALTER TABLE products DROP COLUMN IF EXISTS image;

-- Verificar estrutura da tabela
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'products' 
  AND column_name IN ('image', 'images');
