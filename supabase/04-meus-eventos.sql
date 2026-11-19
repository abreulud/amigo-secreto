-- Execute depois de 03-eventos.sql. A consulta só retorna os eventos da conta conectada.
begin;
create or replace function public.meus_eventos()
returns table(id uuid, nome text, participa boolean)
language sql stable security definer set search_path = '' as $$
  select e.id, e.nome, p.id is not null
  from natal.evento e
  left join natal.pessoa p on p.evento_id = e.id and p.conta = auth.uid()
  where e.organizador = auth.uid() or p.id is not null
  order by e.data, e.nome, e.id;
$$;
revoke all on function public.meus_eventos() from public, anon;
grant execute on function public.meus_eventos() to authenticated;
commit;
