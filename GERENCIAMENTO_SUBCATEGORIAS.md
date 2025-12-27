# 🔐 Gerenciamento de Subcategorias pelo Administrador

## ✅ O que foi implementado

As subcategorias agora são **100% dinâmicas** e gerenciadas exclusivamente pelo administrador através do Supabase. Vendedores e clientes apenas visualizam as subcategorias, sem poder adicionar, editar ou remover.

## 🗄️ Estrutura da Tabela

```sql
CREATE TABLE public.subcategories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  icon text, -- URL da imagem ou caminho do asset
  description text,
  filter_type text NOT NULL, -- Tipo de filtro aplicado
  display_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
```

## 📊 Tipos de Filtro Disponíveis

| Filter Type | Descrição | Critério |
|------------|-----------|----------|
| `maisPopulares` | Mais Populares | Produtos com `clicks_count > 0` |
| `maisComprados` | Mais Comprados | Produtos com `sold_count > 0` |
| `maisBaratos` | Mais Baratos | Todos produtos ordenados por preço crescente |
| `novos` | Novos | Produtos com `created_at < 30 dias` |
| `promocoes` | Promoções | Produtos com `old_price > 0` |
| `recomendados` | Recomendados | Produtos com qualquer métrica > 0 |

## 🚀 Como Executar a Configuração Inicial

### 1. Execute o SQL no Supabase

No **SQL Editor** do Supabase, execute o arquivo:
```
supabase_subcategories_setup.sql
```

Este script:
- ✅ Cria a tabela `subcategories`
- ✅ Configura índices para performance
- ✅ Habilita RLS (Row Level Security)
- ✅ Insere 6 subcategorias padrão
- ✅ Cria trigger para `updated_at`

### 2. Verifique as Subcategorias Criadas

```sql
SELECT * FROM public.subcategories ORDER BY display_order;
```

## 🛠️ Como Gerenciar Subcategorias

### ➕ Adicionar Nova Subcategoria

```sql
INSERT INTO public.subcategories (name, icon, description, filter_type, display_order, active)
VALUES (
  'Ofertas Relâmpago',
  'assets/images/flash.jpg',
  'Ofertas por tempo limitado',
  'promocoes',
  7,
  true
);
```

### ✏️ Editar Subcategoria

```sql
UPDATE public.subcategories
SET 
  name = 'Top Vendidos',
  icon = 'https://nova-url.com/imagem.jpg',
  description = 'Produtos mais vendidos do mês',
  display_order = 1
WHERE id = 'uuid-da-subcategoria';
```

### ❌ Desativar Subcategoria

```sql
UPDATE public.subcategories
SET active = false
WHERE name = 'Mais baratos';
```

### 🗑️ Remover Subcategoria

```sql
DELETE FROM public.subcategories
WHERE name = 'Subcategoria a remover';
```

### 🔄 Reordenar Subcategorias

```sql
-- Alterar ordem de exibição
UPDATE public.subcategories SET display_order = 1 WHERE name = 'Mais populares';
UPDATE public.subcategories SET display_order = 2 WHERE name = 'Novos';
UPDATE public.subcategories SET display_order = 3 WHERE name = 'Promoções';
```

## 🖼️ Gerenciamento de Imagens

### Opção 1: URLs Externas
```sql
UPDATE public.subcategories
SET icon = 'https://meuservidor.com/imagens/subcategoria.jpg'
WHERE name = 'Mais comprados';
```

### Opção 2: Supabase Storage
```sql
-- 1. Fazer upload da imagem no Supabase Storage
-- 2. Copiar URL pública
-- 3. Atualizar subcategoria
UPDATE public.subcategories
SET icon = 'https://hhtoeixaqsnrurnkggkr.supabase.co/storage/v1/object/public/subcategory-images/icon.jpg'
WHERE name = 'Novos';
```

### Opção 3: Assets Locais (Padrão)
```sql
UPDATE public.subcategories
SET icon = 'assets/images/sub1.jpg'
WHERE name = 'Recomendados';
```

## 🔐 Segurança e Permissões

### Row Level Security (RLS)

O RLS está ativado com as seguintes políticas:

**✅ Leitura (SELECT)** - Qualquer pessoa pode visualizar subcategorias ativas:
```sql
CREATE POLICY "Qualquer pessoa pode ver subcategorias ativas"
  ON public.subcategories
  FOR SELECT
  USING (active = true);
```

**🔒 Escrita (INSERT/UPDATE/DELETE)** - Bloqueado por padrão:
```sql
CREATE POLICY "Apenas admins podem gerenciar subcategorias"
  ON public.subcategories
  FOR ALL
  USING (false);
```

### Como Gerenciar como Admin

Use uma das opções:

#### Opção 1: SQL Editor do Supabase Dashboard
- Acesse o **SQL Editor** no Dashboard do Supabase
- Execute comandos diretamente (bypassa RLS)
- ✅ **Recomendado para administração**

#### Opção 2: Service Role Key (API)
```javascript
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

await supabase
  .from('subcategories')
  .insert({ name: 'Nova Subcategoria', ... })
```

## 📱 Como o App Funciona

### Fluxo de Carregamento

1. **App Inicializa**: `SubcategoryService.loadSubcategories()`
2. **Busca Dados**: Query no Supabase com `active = true`
3. **Cache Local**: Armazena subcategorias em memória
4. **Exibição**: UI atualiza automaticamente

### Filtragem Rigorosa

O app aplica filtros rigorosos:
- **Mais Comprados**: Só exibe se `sold_count > 0`
- **Mais Populares**: Só exibe se `clicks_count > 0`
- **Novos**: Só exibe se `created_at < 30 dias`
- **Promoções**: Só exibe se `old_price > 0`

Se nenhum produto atende o critério, a subcategoria **não é mostrada**.

## 🧪 Teste suas Alterações

### 1. Adicione uma Subcategoria de Teste
```sql
INSERT INTO public.subcategories (name, icon, description, filter_type, display_order, active)
VALUES ('Teste Admin', 'assets/images/test.jpg', 'Subcategoria de teste', 'recomendados', 99, true);
```

### 2. Reinicie o App Flutter
```bash
# No terminal, pare o app (Ctrl+C) e execute novamente
flutter run
```

### 3. Verifique no Console
Procure por logs:
```
🔄 Carregando subcategorias do Supabase...
✅ 7 subcategorias carregadas com sucesso!
```

### 4. Remova a Subcategoria de Teste
```sql
DELETE FROM public.subcategories WHERE name = 'Teste Admin';
```

## ⚠️ Avisos Importantes

### ❌ NÃO FAÇA:
- ✘ Não deixe `filter_type` vazio ou com valor inválido
- ✘ Não crie subcategorias com o mesmo nome
- ✘ Não desative todas as subcategorias (deixe pelo menos uma ativa)

### ✅ FAÇA:
- ✓ Use `filter_type` válidos (veja tabela acima)
- ✓ Defina `display_order` para controlar ordem de exibição
- ✓ Use URLs de imagem válidas ou caminhos de assets existentes
- ✓ Teste em ambiente de desenvolvimento antes de produção

## 🔍 Troubleshooting

### Subcategoria não aparece no app

**Verifique:**
1. `active = true`?
2. `filter_type` é válido?
3. Existem produtos que atendem o critério?

```sql
-- Verificar status
SELECT name, active, filter_type, display_order 
FROM public.subcategories 
WHERE name = 'Nome da Subcategoria';

-- Contar produtos por critério
SELECT COUNT(*) FROM products WHERE sold_count > 0; -- Mais Comprados
SELECT COUNT(*) FROM products WHERE clicks_count > 0; -- Mais Populares
SELECT COUNT(*) FROM products WHERE old_price > 0; -- Promoções
```

### App não atualiza após mudanças

**Solução:**
1. Force reload no Flutter: Hot Restart (Shift + R)
2. Limpe cache: `flutter clean && flutter run`
3. Verifique logs no console

### Erro de permissão

Se receber erro ao inserir/atualizar:
- Use o **SQL Editor** do Dashboard (bypassa RLS)
- OU use a **service_role key** na API

## 📚 Arquivos Relacionados

- **SQL Schema**: `supabase_subcategories_setup.sql`
- **Model**: `lib/models/subcategory_model.dart`
- **Service**: `lib/services/subcategory_service.dart`
- **Widget**: `lib/widgets/subcategory_selector.dart`

## 🎯 Próximos Passos

1. ✅ Execute o SQL no Supabase
2. ✅ Verifique subcategorias criadas
3. ✅ Teste o app (deve carregar 6 subcategorias)
4. ✅ Personalize conforme necessário

**Agora você tem controle total sobre as subcategorias sem precisar modificar código!** 🎉
