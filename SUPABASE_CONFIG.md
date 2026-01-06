# 🔧 Configuração do Supabase

## ⚠️ IMPORTANTE: Desabilitar Confirmação de Email

Para que o registro funcione corretamente, você precisa **DESABILITAR** a confirmação de email no Supabase:

### Passos:

1. **Acesse o Dashboard do Supabase**
   - Vá para: https://supabase.com/dashboard

2. **Navegue até Authentication**
   - No menu lateral, clique em **Authentication**
   - Depois clique em **Providers**

3. **Configure o Email Provider**
   - Procure por **Email** na lista de providers
   - Clique para abrir as configurações

4. **Desabilite a Confirmação de Email**
   - Encontre a opção **"Confirm email"** ou **"Enable email confirmations"**
   - **DESMARQUE** esta opção
   - Clique em **Save** para salvar

### Configuração Alternativa (se quiser manter confirmação):

Se você quiser manter a confirmação de email, precisa configurar um serviço de email:

1. **Authentication → Email Templates**
2. Configure um provedor SMTP (Gmail, SendGrid, etc.)
3. Configure os templates de email

---

## ✅ Após Configurar:

1. Execute o SQL no SQL Editor (arquivo `supabase_setup.sql`)
2. Reinicie o aplicativo
3. Teste criando uma nova conta

---

## 📝 Configurações Recomendadas para MVP:

- ✅ **Confirm email**: DESABILITADO
- ✅ **Enable phone confirmations**: DESABILITADO
- ✅ **Enable phone sign-ups**: DESABILITADO
- ✅ **Enable email sign-ups**: HABILITADO

---

## 🔒 Segurança:

Para produção, você deve:
- Habilitar confirmação de email
- Configurar SMTP corretamente
- Adicionar rate limiting
- Configurar políticas RLS mais restritivas
