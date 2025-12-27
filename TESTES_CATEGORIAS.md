# ✅ TESTES: Sistema de Categorias Dinâmicas

## 🎯 Objetivo
Garantir que o sistema de categorias dinâmicas está funcionando perfeitamente.

---

## 📋 PASSO A PASSO COMPLETO

### ✅ TESTE 1: Setup do Supabase (5 minutos)

#### 1.1. Abrir Supabase
- Acesse: https://supabase.com
- Faça login
- Selecione seu projeto: **Wampula Vendas**

#### 1.2. Executar SQL
- Clique em **SQL Editor** (menu lateral esquerdo)
- Clique em **+ New Query**
- Abra o arquivo: `supabase_categories_setup.sql`
- Copie TUDO e cole no SQL Editor
- Clique em **RUN** (ou Ctrl+Enter)

#### 1.3. Verificar Resultado
✅ **Deve aparecer:** "Success. No rows returned" (tudo OK!)
❌ **Se aparecer erro:** Copie a mensagem de erro e me envie

#### 1.4. Confirmar Dados
Execute esta query:
```sql
SELECT name, active, display_order FROM public.categories ORDER BY display_order;
```

✅ **Deve mostrar 9 categorias:**
```
nome              active  display_order
Início            true    0
Eletrónicos       true    1
Família           true    2
Alimentos         true    3
Beleza            true    4
Vestuário         true    5
Casa e Jardim     true    6
Desporto          true    7
Outros            true    8
```

---

### ✅ TESTE 2: App Flutter - Home (3 minutos)

#### 2.1. Limpar e Reconstruir
```bash
cd "C:\Users\Hugo Justino\Documents\Wampula-Vendas-main"
flutter clean
flutter pub get
```

#### 2.2. Executar App
```bash
flutter run -d chrome
# OU
flutter run -d windows
```

#### 2.3. Verificar Logs do Console
Procure por estas mensagens:
```
📂 Carregando categorias do Supabase...
✅ 9 categorias carregadas
```

✅ **Se aparecer:** Tudo OK!
❌ **Se aparecer erro ou "⚠️ Usando categorias padrão":** Problema na conexão com Supabase

#### 2.4. Testar Interface
1. **Veja a barra de categorias no topo**
   - ✅ Deve mostrar: Início, Eletrónicos, Família, etc.
   - ❌ Se mostrar loading infinito: problema de conexão

2. **Clique em cada categoria**
   - ✅ Deve filtrar produtos
   - ✅ "Início" mostra todos os produtos
   - ✅ Outras categorias filtram por categoria

3. **Teste a navegação**
   - ✅ Scroll horizontal funciona suavemente
   - ✅ Categoria selecionada fica destacada

---

### ✅ TESTE 3: Vendedor - Formulário de Produto (2 minutos)

#### 3.1. Fazer Login como Vendedor
- Se não tem conta de vendedor, crie uma:
  1. Faça logout (se logado)
  2. Crie nova conta
  3. Vá em Perfil → Minha Loja → Ativar como vendedor

#### 3.2. Criar Novo Produto
1. Perfil → **Minha Loja**
2. Clique em **+ Adicionar Produto**
3. Procure o campo **Categoria**

#### 3.3. Verificar Dropdown
✅ **Deve mostrar categorias do Supabase (exceto "Início")**
- Eletrónicos
- Família
- Alimentos
- Beleza
- Vestuário
- Casa e Jardim
- Desporto
- Outros

❌ **Se mostrar lista vazia:** Problema ao carregar categorias

#### 3.4. Criar Produto de Teste
1. Preencha os dados:
   - Nome: Teste Categoria
   - Preço: 100
   - Categoria: **Eletrónicos**
   - Descrição: Produto de teste
   - Estoque: 10

2. Clique em **Salvar**
3. ✅ Deve salvar sem erros

---

### ✅ TESTE 4: Adicionar Nova Categoria (2 minutos)

#### 4.1. Adicionar Categoria "Games"
No Supabase SQL Editor, execute:
```sql
INSERT INTO public.categories (name, icon, description, display_order, active) 
VALUES ('Games', '🎮', 'Jogos e consolas', 10, true);
```

✅ **Deve aparecer:** "Success. 1 rows returned"

#### 4.2. Verificar no App
1. **FECHE COMPLETAMENTE o app** (não apenas refresh)
2. **Abra novamente**
3. Vá para a Home

✅ **Deve mostrar:** Nova categoria "Games" na barra

#### 4.3. Verificar no Formulário
1. Vá em **Adicionar Produto**
2. Abra dropdown de **Categoria**

✅ **Deve mostrar:** "Games" nas opções

---

### ✅ TESTE 5: Editar Categoria (1 minuto)

#### 5.1. Renomear Categoria
```sql
UPDATE public.categories 
SET name = 'Jogos' 
WHERE name = 'Games';
```

#### 5.2. Verificar no App
1. Feche e abra o app
2. ✅ Deve mostrar "Jogos" em vez de "Games"

---

### ✅ TESTE 6: Desativar Categoria (1 minuto)

#### 6.1. Desativar "Jogos"
```sql
UPDATE public.categories 
SET active = false 
WHERE name = 'Jogos';
```

#### 6.2. Verificar no App
1. Feche e abra o app
2. ✅ Categoria "Jogos" NÃO deve aparecer

---

### ✅ TESTE 7: Reordenar Categorias (2 minutos)

#### 7.1. Colocar "Beleza" em Primeiro
```sql
-- Salvar ordem atual de Beleza
SELECT display_order FROM public.categories WHERE name = 'Beleza';

-- Trocar posições
UPDATE public.categories SET display_order = 1 WHERE name = 'Beleza';
UPDATE public.categories SET display_order = 4 WHERE name = 'Eletrónicos';
```

#### 7.2. Verificar no App
1. Feche e abra o app
2. ✅ "Beleza" deve aparecer logo após "Início"

#### 7.3. Restaurar Ordem
```sql
UPDATE public.categories SET display_order = 4 WHERE name = 'Beleza';
UPDATE public.categories SET display_order = 1 WHERE name = 'Eletrónicos';
```

---

### ✅ TESTE 8: Produtos Filtram Corretamente (3 minutos)

#### 8.1. Verificar Produto de Teste
1. Vá para a Home
2. Clique na categoria **Eletrónicos**
3. ✅ Deve mostrar o produto "Teste Categoria" criado anteriormente

#### 8.2. Testar Outras Categorias
1. Clique em **Família**
   - ✅ Não deve mostrar "Teste Categoria"
   
2. Clique em **Início**
   - ✅ Deve mostrar TODOS os produtos (incluindo "Teste Categoria")

---

## 🐛 TROUBLESHOOTING

### Problema: App não carrega categorias

#### Sintomas:
- Barra de categorias mostra loading infinito
- Console mostra: "⚠️ Usando categorias padrão (fallback)"

#### Soluções:
1. **Verificar Internet:**
   - Confirme conexão ativa
   
2. **Verificar Supabase:**
   ```sql
   SELECT * FROM public.categories;
   ```
   - Se retornar erro: tabela não existe
   - Execute: `supabase_categories_setup.sql`

3. **Verificar RLS:**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'categories';
   ```
   - Deve haver política de SELECT

4. **Logs do Flutter:**
   ```bash
   flutter run -v
   ```
   - Procure por erros de conexão

---

### Problema: Dropdown vazio no formulário

#### Sintomas:
- Campo "Categoria" não tem opções

#### Soluções:
1. **Verificar categorias ativas:**
   ```sql
   SELECT name, active FROM public.categories WHERE active = true;
   ```
   - Deve ter pelo menos 2 categorias ativas (além de "Início")

2. **Recarregar tela:**
   - Volte e entre novamente no formulário

3. **Verificar logs:**
   - Procure por erros de carregamento de categorias

---

### Problema: Categoria nova não aparece

#### Sintomas:
- Categoria adicionada no Supabase
- Não aparece no app

#### Soluções:
1. **Confirmar inserção:**
   ```sql
   SELECT * FROM public.categories WHERE name = 'SUA_CATEGORIA';
   ```

2. **Verificar active = true:**
   ```sql
   UPDATE public.categories SET active = true WHERE name = 'SUA_CATEGORIA';
   ```

3. **FECHAR E REABRIR APP:**
   - Hot reload não funciona para isso
   - Precisa reiniciar app completamente

---

## 📊 CHECKLIST FINAL

Marque cada item testado:

### Setup
- [ ] SQL executado sem erros
- [ ] 9 categorias criadas no Supabase
- [ ] Query de verificação mostra dados corretos

### Home
- [ ] Barra de categorias visível
- [ ] Logs mostram "X categorias carregadas"
- [ ] Clicar em categoria filtra produtos
- [ ] "Início" mostra todos os produtos
- [ ] Scroll horizontal funciona

### Formulário de Vendedor
- [ ] Dropdown carrega categorias
- [ ] Categorias do Supabase aparecem
- [ ] "Início" NÃO aparece no dropdown
- [ ] Criar produto com categoria funciona

### Operações Dinâmicas
- [ ] Adicionar categoria → aparece no app
- [ ] Editar categoria → mudança reflete
- [ ] Desativar categoria → desaparece do app
- [ ] Reordenar → ordem muda no app
- [ ] Deletar categoria → remove do app

### Performance
- [ ] App carrega rápido
- [ ] Sem travamentos ao trocar categoria
- [ ] Cache funciona (segunda vez mais rápido)

---

## 📝 RELATÓRIO DE TESTES

Ao finalizar, preencha:

**Data do Teste:** __________________

**Plataforma:** ☐ Web ☐ Windows ☐ Android ☐ iOS

**Testes Passados:** _____ / 8

**Problemas Encontrados:**
```
1. _________________________________________________
2. _________________________________________________
3. _________________________________________________
```

**Notas Adicionais:**
```
_____________________________________________________
_____________________________________________________
_____________________________________________________
```

---

## ✅ SUCESSO!

Se todos os testes passaram:
🎉 **Parabéns! Seu sistema de categorias dinâmicas está funcionando perfeitamente!**

Próximos passos:
1. Remover categoria de teste "Jogos"
2. Adicionar categorias reais do seu negócio
3. Começar a adicionar produtos

---

## 🚀 COMANDOS RÁPIDOS

### Ver status geral:
```sql
SELECT 
  c.name,
  c.active,
  c.display_order,
  COUNT(p.id) as produtos
FROM public.categories c
LEFT JOIN public.products p ON p.category = c.name AND p.active = true
GROUP BY c.id, c.name, c.active, c.display_order
ORDER BY c.display_order;
```

### Limpar categorias de teste:
```sql
DELETE FROM public.categories WHERE name IN ('Games', 'Jogos', 'Teste');
```

### Resetar para padrão:
```sql
DELETE FROM public.categories;
-- Depois execute novamente o supabase_categories_setup.sql
```

---

**Happy Testing! 🧪✨**
