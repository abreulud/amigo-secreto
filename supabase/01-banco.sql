begin;
create schema natal;
revoke all on schema natal from public, anon, authenticated;
create table natal.evento (
 singleton boolean primary key default true check(singleton),
 organizador uuid not null references auth.users,
 convite uuid not null default gen_random_uuid(),
 nome text not null default '' check(length(nome)<=60),
 data date, valor numeric check(valor>=0 and valor<=999999),
 vagas integer check(vagas between 3 and 50),
 obs text not null default '' check(length(obs)<=100)
);
create table natal.pessoa (
 id uuid primary key references auth.users,
 nome text not null check(length(trim(nome)) between 1 and 30),
 avisar_data boolean not null default false,
 avisar_lista boolean not null default false
);
create unique index pessoa_nome on natal.pessoa(lower(nome));
create table natal.par (
 de uuid primary key references natal.pessoa,
 para uuid unique not null references natal.pessoa,
 check(de<>para)
);
create table natal.presente (
 id uuid primary key default gen_random_uuid(),
 dono uuid not null references natal.pessoa on delete cascade,
 nome text not null check(length(trim(nome)) between 1 and 70),
 link text not null check(link='' or (length(link)<=2048 and link ~ '^https?://[^[:space:]]+$'))
);
create function public.natal(acao text default 'ler', dados jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 usuario uuid := auth.uid();
 ev natal.evento%rowtype;
 admin boolean;
 membro boolean;
 sorteado boolean;
 total integer;
 alvo uuid;
begin
 if usuario is null then raise exception 'Entre com seu e-mail.'; end if;
 select * into ev from natal.evento for update;
 if not found then raise exception 'Aguardando a configuração do organizador.'; end if;
 admin := ev.organizador=usuario;
 select exists(select from natal.pessoa where id=usuario), exists(select from natal.par),
 (select count(*) from natal.pessoa) into membro,sorteado,total;
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
   returning * into ev;
 when 'entrar' then
   if not admin and ev.convite::text is distinct from dados->>'convite' then raise exception 'Convite inválido.'; end if;
   if membro or sorteado or ev.vagas is null or total>=ev.vagas then raise exception 'Inscrição indisponível.'; end if;
   insert into natal.pessoa(id,nome) values(usuario,trim(dados->>'nome'));
   membro:=true;
 when 'remover' then
   if sorteado then raise exception 'Reabra o grupo primeiro.'; end if;
   delete from natal.pessoa where id=(dados->>'id')::uuid;
   membro:=exists(select from natal.pessoa where id=usuario);
 when 'sortear' then
   if sorteado or total is distinct from ev.vagas then raise exception 'O grupo deve estar completo e aberto.'; end if;
   with ordem as (select id, row_number() over(order by gen_random_uuid()) as pos from natal.pessoa)
   insert into natal.par select a.id,b.id from ordem a join ordem b on b.pos=a.pos%total+1;
   sorteado:=true;
 when 'reabrir' then delete from natal.par; sorteado:=false;
 when 'adicionar' then
   if not membro then raise exception 'Entre no grupo.'; end if;
   insert into natal.presente(dono,nome,link) values(usuario,trim(dados->>'nome'),coalesce(dados->>'link',''));
 when 'excluir' then delete from natal.presente where dono=usuario and id=(dados->>'id')::uuid;
 when 'avisos' then update natal.pessoa set avisar_data=(dados->>'data')::boolean,avisar_lista=(dados->>'lista')::boolean where id=usuario;
 when 'ler' then null;
 else raise exception 'Operação desconhecida.';
 end case;
 if not (membro or admin or ev.convite::text=dados->>'convite') or
 (not membro and not admin and dados->>'convite' is null) then return '{}'::jsonb; end if;
 select para into alvo from natal.par where de=usuario;
 return jsonb_build_object('admin',admin,'me',case when membro then usuario end,
 'convite',case when admin then ev.convite end,'pairs',sorteado,
 'event',jsonb_build_object('name',ev.nome,'date',ev.data,'budget',ev.valor,'count',ev.vagas,'note',ev.obs),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.nome,
 'notifyDate',case when p.id=usuario then p.avisar_data end,'notifyList',case when p.id=usuario then p.avisar_lista end,
 'wishes',coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'text',w.nome,'link',w.link) order by w.nome)
 from natal.presente w where w.dono=p.id and p.id in (usuario,alvo)),'[]'::jsonb)) order by p.nome)
 from natal.pessoa p),'[]'::jsonb),'alvo',alvo);
exception when unique_violation then raise exception 'Esse nome ou cadastro já está em uso.';
end $$;
revoke all on function public.natal(text,jsonb) from public,anon;
grant execute on function public.natal(text,jsonb) to authenticated;
commit;
