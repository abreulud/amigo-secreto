begin;
create or replace function public.atualizar_lista(evento uuid, itens jsonb, avisar_data boolean, avisar_lista boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if jsonb_typeof(itens) is distinct from 'array' then raise exception 'Lista inválida.'; end if;
  perform 1 from natal.evento e where e.id=$1 for update;
  update natal.pessoa p set avisar_data=$3, avisar_lista=$4
    where p.evento_id=$1 and p.conta=auth.uid();
  if not found then raise exception 'Entre no grupo antes de atualizar sua lista.'; end if;
  if jsonb_array_length(itens)>0 then
    perform public.salvar_presentes($1,$2);
  end if;
end $$;
revoke all on function public.atualizar_lista(uuid,jsonb,boolean,boolean) from public,anon;
grant execute on function public.atualizar_lista(uuid,jsonb,boolean,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
