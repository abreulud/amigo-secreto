begin;
create or replace function public.salvar_presentes(evento uuid, itens jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare
  pessoa uuid;
begin
  perform 1 from natal.evento e where e.id=salvar_presentes.evento for update;
  select p.id into pessoa from natal.pessoa p where p.evento_id=evento and p.conta=auth.uid();
  if pessoa is null then raise exception 'Entre no grupo antes de salvar sua lista.'; end if;
  if jsonb_typeof(itens) is distinct from 'array' or jsonb_array_length(itens)=0 then
    raise exception 'Informe pelo menos um presente.';
  end if;
  insert into natal.presente(id,dono,nome,link)
  select i.id,pessoa,trim(i.nome),coalesce(i.link,'')
  from jsonb_to_recordset(itens) as i(id uuid,nome text,link text)
  on conflict(id) do nothing;
end $$;
revoke all on function public.salvar_presentes(uuid,jsonb) from public,anon;
grant execute on function public.salvar_presentes(uuid,jsonb) to authenticated;
commit;
