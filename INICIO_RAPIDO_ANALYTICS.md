# 🚀 INÍCIO RÁPIDO: Sistema de Analytics Dinâmico

## ⚡ 3 Passos Para Ativar

### 1️⃣ Execute o SQL (2 minutos)

```bash
1. Abra Supabase Dashboard → SQL Editor
2. Copie TUDO de: supabase_analytics_system.sql
3. Clique em RUN
4. ✅ Aguarde "Success"
```

### 2️⃣ Verifique (30 segundos)

Execute isto no SQL Editor:

```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'products' 
AND column_name IN ('views_count', 'clicks_count', 'popularity_score');
```

**Deve retornar**: 3 linhas ✅

### 3️⃣ Reinicie o App (10 segundos)

1. **Feche completamente** o app
2. Abra novamente
3. ✅ Pronto!

---

## 🎯 O Que Mudou

### Antes ❌
- Dados fixos no código
- Subcategorias sumiam
- Sem rastreamento real

### Agora ✅
- **Tudo dinâmico** do Supabase
- Rastreamento **automático**:
  - 👁️ Views (ao abrir produto)
  - 🖱️ Cliques (ao clicar no card)
  - 🔍 Pesquisas (ao buscar)
  - 🛒 Vendas (em pedidos reais)
  - ⭐ Popularidade (calculada em tempo real)

---

## 📊 Teste Rápido

Após ativar, faça isto:

1. Abra o app
2. Clique em qualquer produto
3. Execute no Supabase:

```sql
SELECT name, views_count, clicks_count FROM products 
WHERE views_count > 0 OR clicks_count > 0;
```

**Deve ver**: Produto com métricas > 0 ✅

---

## 📚 Documentação Completa

- **Setup**: [supabase_analytics_system.sql](supabase_analytics_system.sql)
- **Guia Completo**: [SISTEMA_ANALYTICS_DINAMICO.md](SISTEMA_ANALYTICS_DINAMICO.md)
- **API Service**: [product_analytics_service.dart](lib/services/product_analytics_service.dart)

---

## 🎁 Bônus: Queries Úteis

### Ver produtos mais populares:
```sql
SELECT name, popularity_score, views_count, sold_count
FROM products
ORDER BY popularity_score DESC
LIMIT 10;
```

### Ver termos mais pesquisados:
```sql
SELECT search_term, COUNT(*) as total
FROM search_logs
GROUP BY search_term
ORDER BY total DESC
LIMIT 10;
```

---

**✅ Sistema 100% Dinâmico - Nada de Dados Fixos!**
