# Amigo Secreto de Natal

O GitHub Pages hospeda a interface em `docs/`. O Supabase autentica as pessoas, guarda o evento e realiza o sorteio. Este projeto atende um grupo de 3 a 50 pessoas. Quem organiza também precisa entrar no grupo se quiser participar. Cada inscrição ocupa uma vaga. Compartilhe o convite apenas com o grupo.

## 1. Preparar o Supabase

1. Crie um projeto em https://supabase.com/dashboard e guarde a senha do banco em local privado.
2. Abra **SQL Editor → New query**, cole o conteúdo de `supabase/01-banco.sql` e clique em **Run** uma vez, em um projeto novo. O script cria as tabelas privadas e a função pública `natal`. Mantenha a Data API habilitada com o esquema `public` exposto.
3. Em **Authentication → Sign In / Providers**, habilite o provedor **Email** e o cadastro de novos usuários. Mantenha a confirmação de e-mail ativa.
4. Em **Authentication → Email Templates**, ajuste os modelos **Magic Link** e **Confirm signup**. Use como corpo `<p>Seu código de acesso ao Amigo Secreto é <strong>{{ .Token }}</strong>.</p>`. O site pede o código digitado, inclusive no primeiro acesso.
5. Configure um servidor **SMTP próprio** em Authentication para enviar os códigos aos convidados. No serviço padrão, o Supabase restringe os destinatários aos endereços autorizados da equipe. Use o host, a porta, o usuário, a senha e o remetente fornecidos pelo seu provedor. Confira também os limites de envio em **Rate Limits**.
6. Em **Connect** ou **Settings → API Keys**, copie a **Project URL** e a **Publishable key**. Preencha `docs/config.js` assim:

```js
window.NATAL_URL = "https://SEU-PROJETO.supabase.co";
window.NATAL_KEY = "sb_publishable_SUA_CHAVE";
```

A chave publicável foi feita para aparecer no navegador. Guarde a senha do banco, a chave secreta do Supabase, service_role, credenciais SMTP e a chave da Resend fora do repositório.

## 2. Publicar no GitHub Pages

1. Extraia o ZIP. No GitHub, use **New repository**, dê o nome `amigo-secreto`, selecione **Public** e crie o repositório. Você pode inicializá-lo com um README para abrir a tela de arquivos.
2. Em **Add file → Upload files**, arraste as pastas `docs` e `supabase` e o `README.md` deste projeto para a raiz. Confira se o caminho é `docs/index.html`. Clique em **Commit changes** na branch `main`.
3. Vá a **Settings → Pages → Build and deployment**. Em **Source**, escolha **Deploy from a branch**, selecione **main** e **/docs**, e clique em **Save**.
4. Acompanhe **Actions → pages build and deployment**. Quando terminar, abra **Settings → Pages → Visit site**. O endereço costuma ser `https://SEU-USUARIO.github.io/amigo-secreto/`.
5. Em **Supabase → Authentication → URL Configuration**, defina **Site URL** como o endereço publicado, incluindo o caminho do repositório. O login deste projeto usa o código digitado na página.

## 3. Ativar o organizador e convidar o grupo

1. Abra o site e solicite um código com seu próprio e-mail. Digite o código e confirme. No primeiro acesso aparecerá “Aguardando a configuração do organizador”.
2. Em **Supabase → Authentication → Users**, encontre seu endereço confirmado e copie o **User UID**.
3. No **SQL Editor**, execute uma vez, trocando o texto entre aspas pelo UID:

```sql
insert into natal.evento (organizador)
values ('COLE-O-UID-AQUI'::uuid);
```

4. Recarregue o site. Na aba **Evento**, informe nome, data, orçamento e quantidade de pessoas. Salve e copie o link de convite. Se você também for participar, abra **Participantes** e cadastre seu nome.
5. Cada convidado abre o link, confirma seu próprio e-mail e cadastra seu nome. Com o número exato de participantes, o organizador pode clicar em **Sorteio → Sortear agora**. Em **Minha área**, cada pessoa toca na etiqueta para revelar o resultado e consulta a lista de quem tirou. Reabra a aba para atualizar.
6. **Refazer sorteio** pede confirmação e apaga os pares anteriores. Ao reabrir o grupo você pode ajustar as inscrições e depois sortear novamente. Os participantes que já abriram o resultado poderão lembrar o nome anterior.
7. Os dados do protótipo antigo ficam no navegador em que foram criados. Faça o cadastro pelo convite para associar cada pessoa à sua conta verificada.

## 4. Ativar lembretes e avisos de lista

O acesso por código usa SMTP. Os avisos do evento usam a API da Resend, o Vault e o agendador do Supabase.

1. Na Resend, verifique seu domínio, escolha um endereço remetente desse domínio e crie uma chave com permissão de envio. Em **Supabase → Vault**, crie os segredos `natal_resend_key` (chave da API Resend) e `natal_remetente` (endereço completo do remetente).
2. Em **SQL Editor**, execute `supabase/02-avisos.sql` uma vez, após o primeiro script. Ele instala pg_net e pg_cron, registra mudanças de lista e agenda a entrega a cada minuto. Se o painel exigir ativação das extensões, habilite **pg_net** e **pg_cron** em **Database → Extensions** e execute o script novamente após o rollback.
3. Cada pessoa pode ativar seus avisos em **Minha área**. O lembrete da troca sai na véspera pelo horário de São Paulo. Uma inclusão ou remoção na lista após o sorteio gera um aviso para quem tirou aquela pessoa, se ela tiver ativado essa preferência.
4. Para conferir os envios, consulte `select estado, count(*) from natal.aviso group by estado;` no SQL Editor e o log de entrega na Resend. O estado **enviado** significa que a API aceitou o e-mail. Falhas têm nova tentativa dentro da janela de 23 horas com a mesma chave de idempotência. Confira remetente, domínio e chave se houver registros expirados.

## 5. Conferir antes de enviar os convites definitivos

Crie um evento com três vagas e use três contas de teste em perfis de navegador separados. Confira o código de primeiro acesso, o bloqueio do sorteio com duas inscrições, os três resultados distintos e a lista mostrada para cada conta. Abra o site com uma quarta conta sem convite e confira a restrição. Ative o aviso de lista, edite um presente depois do sorteio e confira a caixa de entrada de quem tirou essa pessoa. Para testar o lembrete, marque a troca para amanhã e ative a preferência. Antes de usar com o grupo definitivo, reabra o sorteio, remova os participantes de teste e ajuste o evento. A remoção também apaga a lista daquela inscrição.

## Referências

- [Login por código no Supabase](https://supabase.com/docs/guides/auth/auth-email-passwordless)
- [SMTP no Supabase](https://supabase.com/docs/guides/auth/auth-smtp)
- [Publicação por branch no GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
- [Requisições HTTP pelo banco](https://supabase.com/docs/guides/database/extensions/pg_net)
- [Idempotência no envio da Resend](https://resend.com/docs/dashboard/emails/idempotency-keys)
