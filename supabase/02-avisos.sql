begin;
create extension if not exists pg_net;
create extension if not exists pg_cron;
create table natal.aviso (
 chave text primary key,
 destino uuid not null references natal.pessoa on delete cascade,
 origem uuid references natal.pessoa on delete cascade,
 dia date, pedido bigint, tentativa timestamptz, inicio timestamptz, fim timestamptz,
 estado text not null default 'pendente'
);
create function natal.mudou_lista() returns trigger language plpgsql set search_path='' as $$
declare pessoa uuid:=coalesce(new.dono,old.dono);
begin
 insert into natal.aviso(chave,destino,origem)
 select gen_random_uuid()::text,p.de,p.para from natal.par p join natal.pessoa m on m.id=p.de
 where p.para=pessoa and m.avisar_lista;
 return null;
end $$;
create trigger mudou_lista after insert or delete on natal.presente for each row execute function natal.mudou_lista();
create function natal.limpar_par() returns trigger language plpgsql set search_path='' as $$
begin
 delete from natal.aviso where origem=old.para and destino=old.de and estado='pendente';
 return null;
end $$;
create trigger limpar_par after delete on natal.par for each row execute function natal.limpar_par();

create or replace function natal.enviar() returns void language plpgsql set search_path='' as $
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
end $;
revoke all on all functions in schema natal from public,anon,authenticated;
select cron.schedule('natal-avisos','* * * * *','select natal.enviar()');
commit;
