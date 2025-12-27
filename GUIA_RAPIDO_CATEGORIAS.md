# 🎯 GUIA RÁPIDO: 3 Passos para Categorias Dinâmicas

## ⚡ Passo 1: Executar SQL (2 minutos)

1. Abra **Supabase Dashboard** → https://supabase.com
2. Clique em **SQL Editor** (ícone </> no menu lateral)
3. Cole o conteúdo de `supabase_categories_setup.sql`
4. Clique em **RUN** (ou pressione Ctrl+Enter)
5. ✅ Deve aparecer: "Success. No rows returned"

---

## ⚡ Passo 2: Verificar Categorias (30 segundos)

No SQL Editor, execute:

```sql
SELECT name, icon, display_order, active 
FROM public.categories 
ORDER BY display_order;
```

✅ **Deve mostrar 9 categorias:**
- Início 🏠
- Eletrónicos 📱
- Família 👨‍👩‍👧‍👦
- Alimentos 🍎
- Beleza 💄
- Vestuário 👕
- Casa e Jardim 🏡
- Desporto ⚽
- Outros 📦

---

## ⚡ Passo 3: Testar no App (1 minuto)

1. Abra o app Flutter
2. Vá para a **Home**
3. ✅ Deve ver a barra de categorias no topo
4. Clique em cada categoria
5. ✅ Produtos devem filtrar corretamente

### Como Vendedor:
1. Vá em **Perfil → Minha Loja → Adicionar Produto**
2. No campo **Categoria**
3. ✅ Deve mostrar dropdown com categorias do Supabase

---

## 🎨 Exemplos de Uso:

### Adicionar Nova Categoria:
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) 
VALUES ('Automóveis', '🚗', 'Carros e motas', 9, true);
```

### Editar Categoria:
```sql
UPDATE public.categories 
SET name = 'Electrónicos', icon = '⚡' 
WHERE name = 'Eletrónicos';
```

### Desativar Categoria:
```sql
UPDATE public.categories SET active = false WHERE name = 'Outros';
```

### Reordenar:
```sql
UPDATE public.categories SET display_order = 1 WHERE name = 'Beleza';
UPDATE public.categories SET display_order = 2 WHERE name = 'Eletrónicos';
```

---

## 🐛 Problemas Comuns:

### App não mostra categorias:
1. Verifique se executou o SQL
2. Execute: `SELECT * FROM public.categories;`
3. Reinicie o app (fechar completamente e abrir de novo)

### Categoria não aparece:
- Verifique se `active = true`
- Execute: `SELECT name, active FROM public.categories;`

### Erro no dropdown do vendedor:
- Recarregue a tela
- Verifique se há pelo menos 2 categorias ativas (além de "Início")

---

## 📞 Comandos de Debug:

### Ver todas as categorias e status:
```sql
SELECT 
  name,
  active,
  display_order,
  (SELECT COUNT(*) FROM products WHERE category = categories.name) as produtos
FROM public.categories 
ORDER BY display_order;
```

### Ver produtos sem categoria válida:
```sql
SELECT p.name, p.category 
FROM products p
LEFT JOIN categories c ON p.category = c.name
WHERE c.id IS NULL;
```

---

## ✅ Checklist Final:

- [ ] SQL executado sem erros
- [ ] 9 categorias visíveis no Supabase
- [ ] App mostra barra de categorias
- [ ] Clicar em categoria filtra produtos
- [ ] Dropdown de categoria funciona no formulário de produto
- [ ] Adicionar/editar categoria reflete no app

---

## 🎉 Pronto!

**Seu sistema agora é 100% dinâmico!**

Para mais detalhes, consulte:
- `CATEGORIAS_DINAMICAS.md` - Documentação completa
- `RESUMO_CATEGORIAS.md` - Resumo executivo
- `supabase_categories_setup.sql` - Script SQL com comentários

---

**Need help?** Revise os logs do app para mensagens como:
- `📂 Carregando categorias do Supabase...`
- `✅ X categorias carregadas`
