-- Adiciona colunas de formatação da descrição na tabela products
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS description_alignment TEXT DEFAULT 'left',
ADD COLUMN IF NOT EXISTS description_bold BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS description_italic BOOLEAN DEFAULT false;
