-- Execute uma vez, depois de 01-banco.sql. Preserva o convite e as inscrições existentes.
begin;
alter table natal.evento add column id uuid not null default gen_random_uuid();
alter table natal.evento drop column singleton;
alter table natal.evento add primary key(id), add unique(convite);
alter table natal.pessoa add column evento_id uuid references natal.evento, add column conta uuid references auth.users;
update natal.pessoa set evento_id=(select id from natal.evento), conta=id;
alter table natal.pessoa drop constraint pessoa_id_fkey, alter column id set default gen_random_uuid(),
 alter column conta set not null, alter column evento_id set not null, add unique(evento_id,conta);
drop index natal.pessoa_nome;
create unique index pessoa_nome on natal.pessoa(evento_id,lower(nome));
create or replace function public.natal(acao text default 'ler', dados jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 usuario uuid := auth.uid();
 ev natal.evento%rowtype;
 admin boolean;
 membro boolean;
 sorteado boolean;
 total integer;
 alvo uuid;
 inscricao uuid;
 grupos jsonb;
begin
 if usuario is null then raise exception 'Entre com seu e-mail.'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nome',e.nome) order by e.nome,e.id),'[]'::jsonb)
 into grupos from natal.evento e where e.organizador=usuario or exists
 (select from natal.pessoa p where p.evento_id=e.id and p.conta=usuario);
 if acao='criar' then
   insert into natal.evento(id,organizador) values((dados->>'novo')::uuid,usuario)
     on conflict(id) do nothing returning * into ev;
   if not found then
     select * into strict ev from natal.evento where id=(dados->>'novo')::uuid and organizador=usuario for update;
     acao:='ler';
   else
     acao:='evento';
   end if;
 elsif dados->>'convite' is not null then
   select * into ev from natal.evento where convite::text=dados->>'convite' for update;
   if not found then raise exception 'Convite inválido.'; end if;
 elsif dados->>'evento' is not null then
   select * into ev from natal.evento e where e.id=(dados->>'evento')::uuid and
   (e.organizador=usuario or exists(select from natal.pessoa p where p.evento_id=e.id and p.conta=usuario)) for update;
   if not found then raise exception 'Evento indisponível para esta conta.'; end if;
 elsif acao='ler' then return jsonb_build_object('grupos',grupos);
 else raise exception 'Escolha o evento.'; end if;
 admin := ev.organizador=usuario;
 select p.id into inscricao from natal.pessoa p where p.conta=usuario and p.evento_id=ev.id;
 membro:=inscricao is not null;
 select exists(select from natal.par r join natal.pessoa p on p.id=r.de where p.evento_id=ev.id),
 (select count(*) from natal.pessoa where evento_id=ev.id) into sorteado,total;
 if acao in ('evento','remover','sortear','reabrir') and not admin then
   raise exception 'Apenas o organizador pode fazer isso.';
 end if;
 case acao
 when 'evento' then
   if coalesce(trim(dados->>'nome'),'')='' or dados->>'data' is null or dados->>'vagas' is null
     or (dados->>'vagas')::int<total or (sorteado and (dados->>'vagas')::int<>total)
   then raise exception 'Confira o nome, a data e a quantidade de vagas.'; end if;
   update natal.evento set nome=trim(dados->>'nome'),data=(dados->>'data')::date,
   valor=nullif(dados->>'valor','')::numeric,vagas=(dados->>'vagas')::int,obs=coalesce(dados->>'obs','')
   where id=ev.id returning * into ev;
 when 'entrar' then
   if not admin and ev.convite::text is distinct from dados->>'convite' then raise exception 'Convite inválido.'; end if;
   if membro or sorteado or ev.vagas is null or total>=ev.vagas then raise exception 'Inscrição indisponível.'; end if;
   insert into natal.pessoa(conta,evento_id,nome) values(usuario,ev.id,trim(dados->>'nome')) returning id into inscricao;
   membro:=true;
 when 'remover' then
   if sorteado then raise exception 'Reabra o grupo primeiro.'; end if;
   delete from natal.pessoa where evento_id=ev.id and id=(dados->>'id')::uuid;
   membro:=exists(select from natal.pessoa where id=inscricao);
 when 'sortear' then
   if sorteado or total is distinct from ev.vagas then raise exception 'O grupo deve estar completo e aberto.'; end if;
   with ordem as (select id, row_number() over(order by gen_random_uuid()) as pos from natal.pessoa where evento_id=ev.id)
   insert into natal.par select a.id,b.id from ordem a join ordem b on b.pos=a.pos%total+1;
   sorteado:=true;
 when 'reabrir' then delete from natal.par where de in (select id from natal.pessoa where evento_id=ev.id); sorteado:=false;
 when 'adicionar' then
   if not membro then raise exception 'Entre no grupo.'; end if;
   insert into natal.presente(dono,nome,link) values(inscricao,trim(dados->>'nome'),coalesce(dados->>'link',''));
 when 'excluir' then delete from natal.presente where dono=inscricao and id=(dados->>'id')::uuid;
 when 'avisos' then update natal.pessoa set avisar_data=(dados->>'data')::boolean,avisar_lista=(dados->>'lista')::boolean where id=inscricao;
 when 'ler' then null;
 else raise exception 'Operação desconhecida.';
 end case;
 if not (membro or admin or ev.convite::text=dados->>'convite') or
 (not membro and not admin and dados->>'convite' is null) then return '{}'::jsonb; end if;
 select para into alvo from natal.par where de=inscricao;
 return jsonb_build_object('id',ev.id,'grupos',grupos,'admin',admin,'me',case when membro then inscricao end,
 'convite',case when admin then ev.convite end,'pairs',sorteado,
 'event',jsonb_build_object('name',ev.nome,'date',ev.data,'budget',ev.valor,'count',ev.vagas,'note',ev.obs),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.nome,
 'notifyDate',case when p.id=inscricao then p.avisar_data end,'notifyList',case when p.id=inscricao then p.avisar_lista end,
 'wishes',coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'text',w.nome,'link',w.link) order by w.nome)
 from natal.presente w where w.dono=p.id and p.id in (inscricao,alvo)),'[]'::jsonb)) order by p.nome)
 from natal.pessoa p where p.evento_id=ev.id),'[]'::jsonb),'alvo',alvo);
exception when unique_violation then raise exception 'Esse nome ou cadastro já está em uso.';
end $$;
revoke all on function public.natal(text,jsonb) from public,anon;
grant execute on function public.natal(text,jsonb) to authenticated;

create or replace function natal.enviar() returns void language plpgsql set search_path='' as $$
declare
 hoje date:=(now() at time zone 'America/Sao_Paulo')::date;
 api text; remetente text; item record; req bigint;
begin
 if not pg_try_advisory_xact_lock(81261377) then return; end if;
 select decrypted_secret into api from vault.decrypted_secrets where name='natal_resend_key';
 select decrypted_secret into remetente from vault.decrypted_secrets where name='natal_remetente';
 if api is null or remetente is null then return; end if;
 insert into natal.aviso(chave,destino,dia)
 select p.id::text||'/'||e.data::text,p.id,e.data from natal.pessoa p join natal.evento e on e.id=p.evento_id
 where p.avisar_data and e.data=hoje+1 on conflict do nothing;
 update natal.aviso a set estado='enviado',fim=now() from net._http_response r
 where a.estado='pendente' and a.pedido=r.id and r.status_code between 200 and 299;
 update natal.aviso set estado='expirado' where estado='pendente' and inicio<now()-interval '23 hours';
 for item in select a.*,u.email from natal.aviso a join natal.pessoa m on m.id=a.destino
 join auth.users u on u.id=m.conta join natal.evento e on e.id=m.evento_id
 where a.estado='pendente' and (a.tentativa is null or a.tentativa<now()-interval '10 minutes')
 and ((a.origem is null and m.avisar_data and e.data=a.dia and a.dia=hoje+1)
 or (a.origem is not null and m.avisar_lista and exists(select from natal.par p where p.de=m.id and p.para=a.origem)))
 order by a.tentativa nulls first,a.chave limit 5 for update of a
 loop
 select net.http_post(url:='https://api.resend.com/emails',
 headers:=jsonb_build_object('Authorization','Bearer '||api,'Content-Type','application/json','Idempotency-Key',item.chave),
 body:=jsonb_build_object('from',remetente,'to',jsonb_build_array(item.email),'subject','Amigo secreto de Natal',
 'text',case when item.origem is null then 'A troca de presentes é amanhã!' else 'Quem você tirou atualizou a lista. Abra Minha área no site do evento.' end))
 into req;
 update natal.aviso set pedido=req,tentativa=now(),inicio=coalesce(inicio,now()) where chave=item.chave;
 end loop;
end $$;

revoke all on function natal.enviar() from public,anon,authenticated;
commit;
